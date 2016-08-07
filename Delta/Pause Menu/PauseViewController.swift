//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

class PauseViewController: UIViewController, PauseInfoProviding
{
    var emulatorCore: EmulatorCore? {
        didSet {
            self.updatePauseItems()
        }
    }
    
    var pauseItems: [PauseItem] {
        return [self.saveStateItem, self.loadStateItem, self.cheatCodesItem, self.fastForwardItem, self.sustainButtonsItem].flatMap { $0 }
    }
    
    /// Pause Items
    var saveStateItem: PauseItem?
    var loadStateItem: PauseItem?
    var cheatCodesItem: PauseItem?
    var fastForwardItem: PauseItem?
    var sustainButtonsItem: PauseItem?
    
    /// PauseInfoProviding
    var pauseText: String?
    
    /// Cheats
    weak var cheatsViewControllerDelegate: CheatsViewControllerDelegate?
    
    /// Save States
    weak var saveStatesViewControllerDelegate: SaveStatesViewControllerDelegate?
    
    private var saveStatesViewControllerMode = SaveStatesViewController.Mode.loading
    
    private var pauseNavigationController: UINavigationController!
    
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension PauseViewController
{
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        // Ensure navigation bar is always positioned correctly despite being outside the navigation controller's view
        self.pauseNavigationController.navigationBar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.pauseNavigationController.navigationBar.bounds.height)
    }
    
    override func targetViewController(forAction action: Selector, sender: AnyObject?) -> UIViewController?
    {
        return self.pauseNavigationController
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedNavigationController":
            self.pauseNavigationController = segue.destination as! UINavigationController
            self.pauseNavigationController.delegate = self
            self.pauseNavigationController.navigationBar.tintColor = UIColor.deltaLightPurpleColor()
            self.pauseNavigationController.view.backgroundColor = UIColor.clear
            
            let pauseMenuViewController = self.pauseNavigationController.topViewController as! PauseMenuViewController
            pauseMenuViewController.items = self.pauseItems
            
            // Keep navigation bar outside the UIVisualEffectView's
            self.view.addSubview(self.pauseNavigationController.navigationBar)
            
        case "saveStates":
            let saveStatesViewController = segue.destination as! SaveStatesViewController
            saveStatesViewController.delegate = self.saveStatesViewControllerDelegate
            saveStatesViewController.game = self.emulatorCore?.game as? Game
            saveStatesViewController.emulatorCore = self.emulatorCore
            saveStatesViewController.mode = self.saveStatesViewControllerMode
            
        case "cheats":
            let cheatsViewController = segue.destination as! CheatsViewController
            cheatsViewController.delegate = self.cheatsViewControllerDelegate
            cheatsViewController.game = self.emulatorCore?.game as? Game
            
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

private extension PauseViewController
{
    func updatePauseItems()
    {
        self.saveStateItem = nil
        self.loadStateItem = nil
        self.cheatCodesItem = nil
        self.sustainButtonsItem = nil
        self.fastForwardItem = nil
        
        guard self.emulatorCore != nil else { return }
        
        self.saveStateItem = PauseItem(image: UIImage(named: "SaveSaveState")!, text: NSLocalizedString("Save State", comment: ""), action: { [unowned self] _ in
            self.saveStatesViewControllerMode = .saving
            self.performSegue(withIdentifier: "saveStates", sender: self)
        })
        
        self.loadStateItem = PauseItem(image: UIImage(named: "LoadSaveState")!, text: NSLocalizedString("Load State", comment: ""), action: { [unowned self] _ in
            self.saveStatesViewControllerMode = .loading
            self.performSegue(withIdentifier: "saveStates", sender: self)
        })
        
        self.cheatCodesItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Cheat Codes", comment: ""), action: { [unowned self] _ in
            self.performSegue(withIdentifier: "cheats", sender: self)
        })
        
        self.fastForwardItem = PauseItem(image: UIImage(named: "FastForward")!, text: NSLocalizedString("Fast Forward", comment: ""), action: { _ in })
        self.sustainButtonsItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Sustain Buttons", comment: ""), action: { _ in })
    }
}
