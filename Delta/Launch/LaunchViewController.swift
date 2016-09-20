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
    @IBOutlet fileprivate var containerView: UIView!
    fileprivate var gameViewController: GameViewController!
    
    fileprivate var presentedGameViewController: Bool = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.gameViewController?.preferredStatusBarStyle ?? .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.gameViewController?.prefersStatusBarHidden ?? false
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if !self.presentedGameViewController
        {
            self.presentedGameViewController = true
            
            self.gameViewController.performSegue(withIdentifier: "showInitialGamesViewController", sender: nil)
            self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                self.containerView.isHidden = false
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard segue.identifier == "embedGameViewController" else { return }
        
        self.gameViewController = segue.destination as! GameViewController
    }
}
