//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

import DeltaCore

class PauseViewController: UIViewController, PauseInfoProviding
{
    var emulatorCore: EmulatorCore? {
        didSet {
            self.updatePauseItems()
        }
    }
    
    var pauseItems: [MenuItem] {
        return [self.saveStateItem, self.loadStateItem, self.cheatCodesItem, self.fastForwardItem, self.sustainButtonsItem, self.screenshotItem, self.askLuItem].compactMap { $0 }
    }
    
    var closeButtonTitle: String = NSLocalizedString("Main Menu", comment: "")
    
    var menuInsets: UIEdgeInsets? {
        didSet {
            // Do NOT update insets until view is loaded, or else the presentation animation may be incorrect.
            guard self.isViewLoaded else { return }
            
            self.updateSafeAreaInsets()
            self.presentationController?.containerView?.setNeedsLayout()
            self.presentationController?.containerView?.layoutIfNeeded()
        }
    }
    
    /// Pause Items
    var saveStateItem: MenuItem?
    var loadStateItem: MenuItem?
    var cheatCodesItem: MenuItem?
    var fastForwardItem: MenuItem?
    var sustainButtonsItem: MenuItem?
    var screenshotItem: MenuItem?
    var askLuItem: MenuItem?
    
    /// PauseInfoProviding
    var pauseText: String?
    
    /// Cheats
    weak var cheatsViewControllerDelegate: CheatsViewControllerDelegate?
    
    /// Save States
    weak var saveStatesViewControllerDelegate: SaveStatesViewControllerDelegate?
    
    private var saveStatesViewControllerMode = SaveStatesViewController.Mode.loading
    
    private var pauseNavigationController: UINavigationController!
    
    @IBOutlet private var blurView: UIVisualEffectView!
    
    /// UIViewController
    override var preferredContentSize: CGSize {
        set { }
        get
        {
            var preferredContentSize = self.pauseNavigationController.topViewController?.preferredContentSize ?? CGSize.zero
            if preferredContentSize.height > 0
            {
                preferredContentSize.height += self.pauseNavigationController.navigationBar.bounds.height
                
                // Add additionalSafeAreaInsets.bottom (not menuInsets.bottom) because they've already taken existing safe area into account.
                preferredContentSize.height += self.additionalSafeAreaInsets.bottom
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
        
        if #available(iOS 26, *)
        {
            self.blurView.effect = nil
        }
        
        if let gridMenuViewController = self.navigationController?.topViewController as? GridMenuViewController
        {
            if #unavailable(iOS 26)
            {
                gridMenuViewController.resumeButton.image = nil
                gridMenuViewController.resumeButton.title = String(localized: "Resume")
                
                gridMenuViewController.closeButton.image = nil
                gridMenuViewController.closeButton.title = self.closeButtonTitle
                gridMenuViewController.closeButton.tintColor = .systemRed
                gridMenuViewController.closeButton.style = .done
            }
            
            if UIApplication.shared.supportsMultipleScenes
            {
                let openNewMainWindowAction = UIAction(title: NSLocalizedString("Open New Window", comment: ""), image: UIImage(systemName: "macwindow.badge.plus")) { [weak self] _ in
                    self?.openNewMainWindow()
                }
                
                let menu = UIMenu(children: [openNewMainWindowAction])
                gridMenuViewController.closeButton.menu = menu
            }
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        self.updateSafeAreaInsets()
        
        // Ensure we update safe area inset calculations immediately (yes we need both calls).
        self.pauseNavigationController.view.setNeedsLayout()
        self.pauseNavigationController.view.layoutIfNeeded()
    }
    
    func showItems()
    {
        
    }
    
    func hideItems(animated: Bool)
    {
        
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
//            self.pauseNavigationController.navigationBar.backgroundColor = .red
            
            if #available(iOS 26, *)
            {
                let pauseViewController = PauseViewHostingController(items: self.pauseItems) { [weak self] in
                    self?.dismiss()
                } stopHandler: { [weak self] in
                    self?.returnToMainMenu()
                }
                pauseViewController.hideItems(animated: false)
                
                self.pauseNavigationController.setViewControllers([pauseViewController], animated: false)
//                self.pauseNavigationController.setToolbarHidden(false, animated: false) // Hide toolbar to fix layout issues

                // Reset storyboard's barStyle = .black which forces legacy appearance
                // and prevents iOS 26 liquid glass progressive blur.
                self.pauseNavigationController.navigationBar.barStyle = .default
                self.pauseNavigationController.overrideUserInterfaceStyle = .dark
            }
            else
            {
                let gridMenuViewController = self.pauseNavigationController.topViewController as! GridMenuViewController
                gridMenuViewController.items = self.pauseItems
                
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
    func returnToMainMenu()
    {
        self.performSegue(withIdentifier: "unwindToGames", sender: self)
    }
    
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
        
        if #available(iOS 26, *)
        {
            if let collectionViewController = viewController as? UICollectionViewController
            {
                viewController.setContentScrollView(collectionViewController.collectionView, for: .top)
            }
        }
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
        self.screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
        
        if ExperimentalFeatures.shared.variableFastForward.isEnabled, let (menuTitle, menuOptions) = self.makeFastForwardMenu(for: emulatorCore.game)
        {
            self.fastForwardItem?.menuOptions = menuOptions
        }
        // Add Lu menu item if enabled
        if ExperimentalFeatures.shared.Lu.isEnabled {
            self.askLuItem = self.configureLuMenuItem()
        }
    }
    
    func updateSafeAreaInsets()
    {
        func absoluteValue(for inset: Double, dimension: Double) -> Double
        {
            // Convert relative insets into absolute insets.
            guard inset > 0 && inset <= 1.0 else { return inset }
            
            let absoluteValue = inset * dimension
            return absoluteValue
        }
        
        if let menuInsets, let window = self.view.window
        {
            var absoluteMenuInsets = UIEdgeInsets.zero
            absoluteMenuInsets.left = absoluteValue(for: menuInsets.left, dimension: self.view.bounds.width)
            absoluteMenuInsets.right = absoluteValue(for: menuInsets.right, dimension: self.view.bounds.width)
            absoluteMenuInsets.top = absoluteValue(for: menuInsets.top, dimension: self.view.bounds.height)
            absoluteMenuInsets.bottom = absoluteValue(for: menuInsets.bottom, dimension: self.view.bounds.height)
            
            // Subtract default safe area insets from menuInsets for "additional" insets
            self.additionalSafeAreaInsets.left = max(absoluteMenuInsets.left - window.safeAreaInsets.left, 0)
            self.additionalSafeAreaInsets.right = max(absoluteMenuInsets.right - window.safeAreaInsets.right, 0)
            self.additionalSafeAreaInsets.top = max(absoluteMenuInsets.top - window.safeAreaInsets.top, 0)
            self.additionalSafeAreaInsets.bottom = max(absoluteMenuInsets.bottom - window.safeAreaInsets.bottom, 0)
        }
        else
        {
            self.additionalSafeAreaInsets = .zero
        }
    }
    
    func makeFastForwardMenu(for game: GameProtocol) -> (title: String, options: [Action])?
    {
        guard let deltaCore = Delta.core(for: game.type), #available(iOS 15, *) else { return nil }
        
        let menuTitle = NSLocalizedString("Change the Fast Forward speed for this system.", comment: "")
        
        let preferredSpeed = ExperimentalFeatures.shared.variableFastForward[game.type]
        let supportedSpeeds = FastForwardSpeed.speeds(in: deltaCore.supportedRates)
        
        var menuOptions = zip(0..., supportedSpeeds).map { (index, speed) in
            
            let style: Action.Style = (speed == preferredSpeed) ? .selected : .default
            var action = Action(title: speed.description, style: style) { action in
                ExperimentalFeatures.shared.variableFastForward[game.type] = speed
                
                if let fastForwardItem = self.fastForwardItem
                {
                    if #unavailable(iOS 26)
                    {
                        fastForwardItem.isSelected = true // Always enable FF after selecting speed.
                    }
                    else
                    {
                        // Except on iOS 26, where we toggle it in the callback (TODO: Change the callback to fix this)
                    }
                    
                    
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

        let style: Action.Style = (preferredSpeed == nil) ? .selected : .default
        let action = Action(title: NSLocalizedString("Maximum", comment: ""), style: style) { action in
            ExperimentalFeatures.shared.variableFastForward[game.type] = nil
            
            if let fastForwardItem = self.fastForwardItem
            {
                fastForwardItem.isSelected = true // Always enable FF after selecting speed.
                fastForwardItem.action(fastForwardItem)
            }
        }
        menuOptions.append(action)
        
        return (menuTitle, menuOptions)
    }
    
    func openNewMainWindow()
    {
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = self.view.window?.windowScene
        
        if #available(iOS 17, *)
        {
            let request = UISceneSessionActivationRequest(role: .windowApplication, options: options)
            UIApplication.shared.activateSceneSession(for: request) { error in
                Logger.main.error("Failed to open new main window. \(error.localizedDescription, privacy: .public)")
            }
        }
        else
        {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: options) { error in
                Logger.main.error("Failed to open new main window. \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
