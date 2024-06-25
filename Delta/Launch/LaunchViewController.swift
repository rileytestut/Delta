//
//  LaunchViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/8/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

import Harmony

class LaunchViewController: RSTLaunchViewController
{
    var deepLinkGame: Game?
    
    @IBOutlet private var gameViewContainerView: UIView!
    private(set) var gameViewController: GameViewController!
    
    private var presentedGameViewController: Bool = false
    
    private var didAttemptStartingSyncManager = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.gameViewController?.preferredStatusBarStyle ?? .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.gameViewController?.prefersStatusBarHidden ?? false
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return self.gameViewController
    }
    
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return self.gameViewController
    }
    
    override var shouldAutorotate: Bool {
        return self.gameViewController?.shouldAutorotate ?? true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return self.gameViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "embedGameViewController" else { return }
        
        self.gameViewController = segue.destination as? GameViewController
    }
}

extension LaunchViewController
{
    override var launchConditions: [RSTLaunchCondition] {
        let isDatabaseManagerStarted = RSTLaunchCondition(condition: { DatabaseManager.shared.isStarted }) { (completionHandler) in
            DatabaseManager.shared.start(completionHandler: completionHandler)
        }
        
        let isSyncingManagerStarted = RSTLaunchCondition(condition: { self.didAttemptStartingSyncManager }) { (completionHandler) in
            self.didAttemptStartingSyncManager = true
            
            SyncManager.shared.start(service: Settings.syncingService) { (result) in
                switch result
                {
                case .success: completionHandler(nil)
                case .failure(let error): completionHandler(error)
                }
            }
        }
        
        // Repair database _after_ starting SyncManager so we can access RecordController.
        let isDatabaseRepaired = RSTLaunchCondition(condition: { !UserDefaults.standard.shouldRepairDatabase }) { completionHandler in
            let repairViewController = RepairDatabaseViewController()
            repairViewController.completionHandler = { [weak repairViewController] in
                repairViewController?.dismiss(animated: true)
                
                UserDefaults.standard.shouldRepairDatabase = false
                completionHandler(nil)
            }
            
            let navigationController = UINavigationController(rootViewController: repairViewController)
            self.present(navigationController, animated: true)
        }
        
        return [isDatabaseManagerStarted, isSyncingManagerStarted, isDatabaseRepaired]
    }
    
    override func handleLaunchError(_ error: Error)
    {
        do
        {
            throw error
        }
        catch is HarmonyError
        {
            // Ignore
            self.handleLaunchConditions()
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Unable to Launch Delta", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .default, handler: { (action) in
                self.handleLaunchConditions()
            }))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    override func finishLaunching()
    {
        super.finishLaunching()
        
        guard !self.presentedGameViewController else { return }
        self.presentedGameViewController = true
        
        PatreonAPI.shared.refreshPatreonAccount()
        
        func showGameViewController()
        {
            self.view.bringSubviewToFront(self.gameViewContainerView)
            
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        
        if let deepLinkGame, deepLinkGame != (self.gameViewController.game as? Game)
        {
            // Set GameViewController's game to deepLinkGame only if it's a different game.
            self.gameViewController.game = deepLinkGame
        }
        
        if self.gameViewController.game != nil
        {
            // self.deepLinkGame may be nil, but if gameViewController.game isn't then show it anyway.
            
            UIView.transition(with: self.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                showGameViewController()
            }) { (finished) in
                self.gameViewController.viewDidAppear(true)
                self.gameViewController.startEmulation()
            }
        }
        else
        {
            self.gameViewController.performSegue(withIdentifier: "showInitialGamesViewController", sender: nil)
            self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                showGameViewController()
            })
        }
    }
}
