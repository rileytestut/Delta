//
//  EmulationViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import SNESDeltaCore

class EmulationViewController: UIViewController
{
    //MARK: - Properties -
    /** Properties **/
    
    /// Should only be set when preparing for segue. Otherwise, should be considered immutable
    var game: Game! {
        didSet
        {
            guard oldValue != game else { return }

            self.emulatorCore = SNESEmulatorCore(game: game)
            self.preferredContentSize = self.emulatorCore.preferredRenderingSize
        }
    }
    private(set) var emulatorCore: EmulatorCore!
    
    //MARK: - Private Properties
    @IBOutlet private var controllerView: ControllerView!
    @IBOutlet private var gameView: GameView!
    
    @IBOutlet private var controllerViewHeightConstraint: NSLayoutConstraint!
    
    private var isPreviewing: Bool {
        guard let presentationController = self.presentationController else { return false }
        return NSStringFromClass(presentationController.dynamicType).containsString("PreviewPresentation")
    }

    
    //MARK: - Initializers -
    /** Initializers **/
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
                
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("updateControllers"), name: ExternalControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("updateControllers"), name: ExternalControllerDidDisconnectNotification, object: nil)
    }
    
    deinit
    {
        // To ensure the emulation stops when cancelling a peek/preview gesture
        self.emulatorCore.stopEmulation()
    }
    
    //MARK: - Overrides
    /** Overrides **/
    
    //MARK: - UIViewController
    /// UIViewController
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Set this to 0 now and update it in viewDidLayoutSubviews to ensure there are never conflicting constraints
        // (such as when peeking and popping)
        self.controllerViewHeightConstraint.constant = 0
        
        self.gameView.backgroundColor = UIColor.clearColor()
        self.emulatorCore.addGameView(self.gameView)
        
        let controllerSkin = ControllerSkin.defaultControllerSkinForGameUTI(self.game.typeIdentifier)
        
        self.controllerView.containerView = self.view
        self.controllerView.controllerSkin = controllerSkin
        self.controllerView.addReceiver(self)
        self.emulatorCore.setGameController(self.controllerView, atIndex: 0)
        
        self.updateControllers()
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCore.startEmulation()
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if Settings.localControllerPlayerIndex != nil && self.controllerView.intrinsicContentSize() != CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric) && !self.isPreviewing
        {
            let scale = self.view.bounds.width / self.controllerView.intrinsicContentSize().width
            self.controllerViewHeightConstraint.constant = self.controllerView.intrinsicContentSize().height * scale
        }
        else
        {
            self.controllerViewHeightConstraint.constant = 0
        }
    }
    
    override func prefersStatusBarHidden() -> Bool
    {
        return true
    }
    
    /// <UIContentContainer>
    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)
        
        self.controllerView.beginAnimatingUpdateControllerSkin()
        
        coordinator.animateAlongsideTransition(nil) { (context) in
            self.controllerView.finishAnimatingUpdateControllerSkin()
        }
    }
    
    //MARK: - Controllers -
    /// Controllers
    func updateControllers()
    {
        self.emulatorCore.removeAllGameControllers()
        
        if let index = Settings.localControllerPlayerIndex
        {
            self.emulatorCore.setGameController(self.controllerView, atIndex: index)
        }
        
        for controller in ExternalControllerManager.sharedManager.connectedControllers
        {
            if let index = controller.playerIndex
            {
                self.emulatorCore.setGameController(controller, atIndex: index)
            }
        }
        
        self.view.setNeedsLayout()
    }
    
    //MARK: - 3D Touch -
    /// 3D Touch
    override func previewActionItems() -> [UIPreviewActionItem]
    {
        let presentingViewController = self.presentingViewController
        
        let launchGameAction = UIPreviewAction(title: NSLocalizedString("Launch \(self.game.name)", comment: ""), style: .Default) { (action, viewController) in
            // Delaying until next run loop prevents self from being dismissed immediately
            dispatch_async(dispatch_get_main_queue()) {
                presentingViewController?.presentViewController(viewController, animated: true, completion: nil)
            }
        }
        return [launchGameAction]
    }
}

//MARK: - <GameControllerReceiver> -
/// <GameControllerReceiver>
extension EmulationViewController: GameControllerReceiverType
{
    func gameController(gameController: GameControllerType, didActivateInput input: InputType)
    {
        if UIDevice.currentDevice().supportsVibration
        {
            UIDevice.currentDevice().vibrate()
        }
        
        guard let input = input as? ControllerInput else { return }
        
        print("Activated \(input)")
    }
    
    func gameController(gameController: GameControllerType, didDeactivateInput input: InputType)
    {
        guard let input = input as? ControllerInput else { return }
        
        print("Deactivated \(input)")
    }
}
