//
//  LaunchViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/8/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class LaunchViewController: UIViewController
{
    @IBOutlet private var gameViewContainerView: UIView!
    private var gameViewController: GameViewController!
    
    private var presentedGameViewController: Bool = false
    
    private var applicationLaunchDeepLinkGame: Game?
    
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
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if !self.presentedGameViewController
        {
            self.presentedGameViewController = true
            
            func showGameViewController()
            {
                self.view.bringSubviewToFront(self.gameViewContainerView)
                
                self.setNeedsStatusBarAppearanceUpdate()
                
                if #available(iOS 11.0, *)
                {
                    self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                }
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "embedGameViewController" else { return }
        
        self.gameViewController = segue.destination as? GameViewController
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
