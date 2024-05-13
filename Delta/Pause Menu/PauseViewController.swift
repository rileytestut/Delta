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
    
    var pauseItems: [MenuItem] {
        return [self.saveStateItem, self.loadStateItem, self.cheatCodesItem, self.fastForwardItem, self.sustainButtonsItem, self.screenshotItem].compactMap { $0 }
    }
    
    var closeButtonTitle: String = NSLocalizedString("Main Menu", comment: "")
    
    /// Pause Items
    var saveStateItem: MenuItem?
    var loadStateItem: MenuItem?
    var cheatCodesItem: MenuItem?
    var fastForwardItem: MenuItem?
    var sustainButtonsItem: MenuItem?
    var screenshotItem: MenuItem?
    
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
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        
        if let gridMenuViewController = self.navigationController?.topViewController as? GridMenuViewController
        {
            gridMenuViewController.closeButton.title = self.closeButtonTitle
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        self.updateSafeAreaInsets()
    }
}

extension PauseViewController
{
    override func targetViewController(forAction action: Selector, sender: Any?) -> UIViewController?
    {
        return self.pauseNavigationController
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedNavigationController":
            self.pauseNavigationController = segue.destination as? UINavigationController
            self.pauseNavigationController.delegate = self
            self.pauseNavigationController.navigationBar.tintColor = UIColor.deltaPurple
            self.pauseNavigationController.view.backgroundColor = UIColor.clear
            
            let gridMenuViewController = self.pauseNavigationController.topViewController as! GridMenuViewController
            
            if #available(iOS 13.0, *)
            {
                let navigationBarAppearance = self.pauseNavigationController.navigationBar.standardAppearance.copy()
                navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .dark)
                navigationBarAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                navigationBarAppearance.shadowColor = UIColor.white.withAlphaComponent(0.2)
                navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                self.pauseNavigationController.navigationBar.standardAppearance = navigationBarAppearance
                
                let transparentBarAppearance = navigationBarAppearance.copy()
                transparentBarAppearance.backgroundColor = nil
                transparentBarAppearance.backgroundEffect = nil
                gridMenuViewController.navigationItem.standardAppearance = transparentBarAppearance
            }
            
            gridMenuViewController.items = self.pauseItems
            
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
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        let transitionCoordinator = PauseTransitionCoordinator(presentationController: self.presentationController!)
        transitionCoordinator.presenting = (operation == .push)
        return transitionCoordinator
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool)
    {
        self.updateSafeAreaInsets()
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
        self.screenshotItem = nil
        
        guard let emulatorCore = self.emulatorCore else { return }
        
        self.saveStateItem = MenuItem(text: NSLocalizedString("Save State", comment: ""), image: #imageLiteral(resourceName: "SaveSaveState"), action: { [unowned self] _ in
            self.saveStatesViewControllerMode = .saving
            self.performSegue(withIdentifier: "saveStates", sender: self)
        })
        
        self.loadStateItem = MenuItem(text: NSLocalizedString("Load State", comment: ""), image: #imageLiteral(resourceName: "LoadSaveState"), action: { [unowned self] _ in
            self.saveStatesViewControllerMode = .loading
            self.performSegue(withIdentifier: "saveStates", sender: self)
        })
        
        self.cheatCodesItem = MenuItem(text: NSLocalizedString("Cheat Codes", comment: ""), image: #imageLiteral(resourceName: "CheatCodes"), action: { [unowned self] _ in
            self.performSegue(withIdentifier: "cheats", sender: self)
        })
        
        self.fastForwardItem = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { _ in })
        self.sustainButtonsItem = MenuItem(text: NSLocalizedString("Hold Buttons", comment: ""), image: #imageLiteral(resourceName: "SustainButtons"), action: { _ in })
        
        if ExperimentalFeatures.shared.gameScreenshots.isEnabled
        {
            self.screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
        }
        
        if ExperimentalFeatures.shared.variableFastForward.isEnabled
        {
            let menu = self.makeFastForwardMenu(for: emulatorCore.game)
            self.fastForwardItem?.menu = menu
        }
    }
    
    func updateSafeAreaInsets()
    {
        if self.navigationController?.topViewController == self.navigationController?.viewControllers.first
        {
            self.additionalSafeAreaInsets.left = self.view.window?.safeAreaInsets.left ?? 0
            self.additionalSafeAreaInsets.right = self.view.window?.safeAreaInsets.right ?? 0
        }
        else
        {
            self.additionalSafeAreaInsets.left = 0
            self.additionalSafeAreaInsets.right = 0
        }
    }
    
    func makeFastForwardMenu(for game: GameProtocol) -> UIMenu?
    {
        guard let deltaCore = Delta.core(for: game.type), #available(iOS 15, *) else { return nil }
        
        let menu = UIMenu(title: NSLocalizedString("Change the Fast Forward speed for this system.", comment: ""), options: [.singleSelection], children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                let preferredSpeed = ExperimentalFeatures.shared.variableFastForward[game.type]
                
                let supportedSpeeds = FastForwardSpeed.speeds(in: deltaCore.supportedRates)
                var actions = zip(0..., supportedSpeeds).map { (index, speed) in
                    
                    let state: UIAction.State = (speed == preferredSpeed) ? .on : .off
                    let action = UIAction(title: speed.description, state: state) { action in
                        ExperimentalFeatures.shared.variableFastForward[game.type] = speed
                        
                        if let fastForwardItem = self?.fastForwardItem
                        {
                            fastForwardItem.isSelected = true // Always enable FF after selecting speed.
                            fastForwardItem.action(fastForwardItem)
                        }
                    }
                    
                    if #available(iOS 16, *)
                    {
                        let configuration = UIImage.SymbolConfiguration(hierarchicalColor: .deltaPurple)
                        
                        let percentage = Double(index + 1) / Double(supportedSpeeds.count)
                        action.image = UIImage(systemName: "timelapse", variableValue: percentage, configuration: configuration)
                    }
                    
                    return action
                }

                let state: UIAction.State = (preferredSpeed == nil) ? .on : .off
                let action = UIAction(title: NSLocalizedString("Maximum", comment: ""), state: state) { action in
                    ExperimentalFeatures.shared.variableFastForward[game.type] = nil
                    
                    if let fastForwardItem = self?.fastForwardItem
                    {
                        fastForwardItem.isSelected = true // Always enable FF after selecting speed.
                        fastForwardItem.action(fastForwardItem)
                    }
                }
                actions.append(action)
                
                completion(actions)
            }
        ])
        
        return menu
    }
}
