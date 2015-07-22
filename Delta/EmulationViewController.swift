//
//  EmulationViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

class EmulationViewController: UIViewController
{
    //MARK: - Properties -
    /** Properties **/
    let game: Game
    let emulatorCore: EmulatorCore
    @IBOutlet private(set) var controllerView: ControllerView!
    
    //MARK: - Private Properties
    @IBOutlet private var controllerViewHeightConstraint: NSLayoutConstraint!
    
    //MARK: - Initializers -
    /** Initializers **/
    required init(game: Game)
    {
        self.game = game
        self.emulatorCore = EmulatorCore(game: game)
        
        super.init(nibName: "EmulationViewController", bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("initWithCoder: not implemented.")
    }
    
    //MARK: - Overrides -
    /** Overrides **/
    
    //MARK: - UIViewController
    /// UIViewController
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let controllerSkin = ControllerSkin.defaultControllerSkinForGameUTI(self.game.UTI)
        
        self.controllerView.controllerSkin = controllerSkin
        self.controllerView.addReceiver(self)
        self.emulatorCore.setGameController(self.controllerView, atIndex: 0)
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCore.startEmulation()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let scale = self.view.bounds.width / self.controllerView.intrinsicContentSize().width
        self.controllerViewHeightConstraint.constant = self.controllerView.intrinsicContentSize().height * scale
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
