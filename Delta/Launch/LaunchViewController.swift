//
//  LaunchViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/8/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class LaunchViewController: UIViewController
{
    @IBOutlet private var gameViewContainerView: UIView!
    private var gameViewController: GameViewController!
    
    private var presentedGameViewController: Bool = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.gameViewController?.preferredStatusBarStyle ?? .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.gameViewController?.prefersStatusBarHidden ?? false
    }
    
    override func childViewControllerForHomeIndicatorAutoHidden() -> UIViewController? {
        return self.gameViewController
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if !self.presentedGameViewController
        {
            self.presentedGameViewController = true
            
            self.gameViewController.performSegue(withIdentifier: "showInitialGamesViewController", sender: nil)
            self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                self.view.bringSubview(toFront: self.gameViewContainerView)
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "embedGameViewController" else { return }
        
        self.gameViewController = segue.destination as! GameViewController
    }
}
