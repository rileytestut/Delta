//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class PauseViewController: UIViewController, PauseInfoProvidable
{
    /// Pause Items
    var items = [PauseItem]()
    
    /// <PauseInfoProvidable>
    var pauseText: String? = nil
    
    private weak var saveStatesViewControllerDelegate: SaveStatesViewControllerDelegate?
    private var saveStatesViewControllerMode = SaveStatesViewController.Mode.saving
    
    private weak var cheatsViewControllerDelegate: CheatsViewControllerDelegate?
    
    /// UIViewController
    override var preferredContentSize: CGSize {
        set { }
        get
        {
            var preferredContentSize = self.pauseNavigationController.topViewController?.preferredContentSize ?? CGSize.zero
            if preferredContentSize.height > 0
            {
                preferredContentSize.height += self.pauseNavigationController.navigationBar.bounds.height
            }
            
            return preferredContentSize
        }
    }
    
    override var navigationController: UINavigationController? {
        return self.pauseNavigationController
    }
    
    private var pauseNavigationController: UINavigationController!
}

extension PauseViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle
    {
        return .lightContent
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        // Ensure navigation bar is always positioned correctly despite being outside the navigation controller's view
        self.pauseNavigationController.navigationBar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.pauseNavigationController.navigationBar.bounds.height)
    }
    
    override func targetViewController(forAction action: Selector, sender: AnyObject?) -> UIViewController? {
        return self.pauseNavigationController
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        switch segue.identifier ?? ""
        {
        case "embedNavigationController":
            self.pauseNavigationController = segue.destinationViewController as! UINavigationController
            self.pauseNavigationController.delegate = self
            self.pauseNavigationController.navigationBar.tintColor = UIColor.deltaLightPurpleColor()
            self.pauseNavigationController.view.backgroundColor = UIColor.clear()
            
            let pauseMenuViewController = self.pauseNavigationController.topViewController as! PauseMenuViewController
            pauseMenuViewController.items = self.items
            
            // Keep navigation bar outside the UIVisualEffectView's
            self.view.addSubview(self.pauseNavigationController.navigationBar)
            
        case "saveStates":
            let saveStatesViewController = segue.destinationViewController as! SaveStatesViewController
            saveStatesViewController.delegate = self.saveStatesViewControllerDelegate
            saveStatesViewController.mode = self.saveStatesViewControllerMode
            
        case "cheats":
            let cheatsViewController = segue.destinationViewController as! CheatsViewController
            cheatsViewController.delegate = self.cheatsViewControllerDelegate
            
        default: break
        }
    }
}

extension PauseViewController
{
    func dismiss()
    {
        self.performSegue(withIdentifier: "unwindFromPauseMenu", sender: self)
    }
    
    func presentSaveStateViewControllerWithMode(_ mode: SaveStatesViewController.Mode, delegate: SaveStatesViewControllerDelegate)
    {
        self.saveStatesViewControllerMode = mode
        self.saveStatesViewControllerDelegate = delegate
        
        self.performSegue(withIdentifier: "saveStates", sender: self)
    }
    
    func presentCheatsViewController(delegate: CheatsViewControllerDelegate)
    {
        self.cheatsViewControllerDelegate = delegate
        
        self.performSegue(withIdentifier: "cheats", sender: self)
    }
}

extension PauseViewController: UINavigationControllerDelegate
{
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        let transitionCoordinator = PauseTransitionCoordinator(presentationController: self.presentationController!)
        transitionCoordinator.presenting = (operation == .push)
        return transitionCoordinator
    }
}
