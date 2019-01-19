//
//  LaunchViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/8/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class LaunchViewController: RSTLaunchViewController
{
    @IBOutlet private var gameViewContainerView: UIView!
    private var gameViewController: GameViewController!
    
    private var presentedGameViewController: Bool = false
    
    private var applicationLaunchDeepLinkGame: Game?
    
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
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(LaunchViewController.deepLinkControllerLaunchGame(with:)), name: .deepLinkControllerLaunchGame, object: nil)
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
            SyncManager.shared.syncCoordinator.start { (error) in
                self.didAttemptStartingSyncManager = true
                completionHandler(nil)
            }
        }
        
        return [isDatabaseManagerStarted, isSyncingManagerStarted]
    }
    
    override func handleLaunchError(_ error: Error)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Unable to Launch Delta", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: ""), style: .default, handler: { (action) in
            self.handleLaunchConditions()
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func finishLaunching()
    {
        super.finishLaunching()
        
        guard !self.presentedGameViewController else { return }
        
        self.presentedGameViewController = true
        
        func showGameViewController()
        {
            self.view.bringSubviewToFront(self.gameViewContainerView)
            
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        
        if let game = self.applicationLaunchDeepLinkGame
        {
            self.gameViewController.game = game
            
            UIView.transition(with: self.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                showGameViewController()
            }, completion: nil)
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

private extension LaunchViewController
{
    @objc func deepLinkControllerLaunchGame(with notification: Notification)
    {
        guard !self.presentedGameViewController else { return }
        
        guard let game = notification.userInfo?[DeepLink.Key.game] as? Game else { return }
        
        self.applicationLaunchDeepLinkGame = game
    }
}
