//
//  GameViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

class GameViewController: DeltaCore.GameViewController
{
    /// Assumed to be Delta.Game instance
    override var game: GameProtocol? {
        didSet {
            guard let emulatorCore = self.emulatorCore else { return }
            self.preferredContentSize = emulatorCore.preferredRenderingSize
        }
    }
    
    // If non-nil, will override the default preview action items returned in previewActionItems()
    var overridePreviewActionItems: [UIPreviewActionItem]?
    
    //MARK: - Private Properties -
    private var pauseViewController: PauseViewController?
    private var pausingGameController: GameController?
    
    required init()
    {
        super.init()
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateControllers), name: .externalControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateControllers), name: .externalControllerDidDisconnect, object: nil)
    }
    
    // MARK: GameControllerReceiver -
    override func gameController(_ gameController: GameController, didActivate input: Input)
    {
        super.gameController(gameController, didActivate: input)
        
        if gameController is ControllerView && UIDevice.current().isVibrationSupported
        {
            UIDevice.current().vibrate()
        }
    }
}


//MARK: UIViewController -
/// UIViewController
extension GameViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.updateControllers()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        self.controllerView.isHidden = self.isPreviewing
    }
    
    override func previewActionItems() -> [UIPreviewActionItem]
    {
        if let previewActionItems = self.overridePreviewActionItems
        {
            return previewActionItems
        }
        
        guard let game = self.game as? Game else { return [] }
        
        let presentingViewController = self.presentingViewController
        
        let launchGameAction = UIPreviewAction(title: NSLocalizedString("Launch \(game.name)", comment: ""), style: .default) { (action, viewController) in
            // Delaying until next run loop prevents self from being dismissed immediately
            DispatchQueue.main.async {
                presentingViewController?.present(viewController, animated: true, completion: nil)
            }
        }
        return [launchGameAction]
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let identifier = segue.identifier where identifier == "pause" else { return }
        
        guard let gameController = sender as? GameController else {
            fatalError("sender for pauseSegue must be the game controller that pressed the Menu button")
        }
        
        self.pausingGameController = gameController
        
        let pauseViewController = segue.destinationViewController as! PauseViewController
        pauseViewController.pauseText = (self.game as? Game)?.name ?? NSLocalizedString("Delta", comment: "")
        pauseViewController.emulatorCore = self.emulatorCore
        self.pauseViewController = pauseViewController
    }
    
    @IBAction private func unwindFromPauseViewController(_ segue: UIStoryboardSegue)
    {        
        self.pauseViewController = nil
        self.pausingGameController = nil
        
        if self.resumeEmulation()
        {
            // Temporarily disable audioManager to prevent delayed audio bug when using 3D Touch Peek & Pop
            self.emulatorCore?.audioManager.enabled = false
            
            // Re-enable after delay
            DispatchQueue.main.after(when: .now() + 0.1) {
                self.emulatorCore?.audioManager.enabled = true
            }
        }
    }
}

//MARK: Controllers -
private extension GameViewController
{
    @objc func updateControllers()
    {
        self.emulatorCore?.removeAllGameControllers()
        
        if let index = Settings.localControllerPlayerIndex
        {
            self.controllerView.playerIndex = index
        }
        
        var controllers = [GameController]()
        controllers.append(self.controllerView)
        
        // We need to map each item as a GameControllerProtocol due to a Swift bug
        controllers.append(contentsOf: ExternalControllerManager.shared.connectedControllers.map { $0 as GameController })
        
        for controller in controllers
        {
            if let index = controller.playerIndex
            {
                // We need to place the underscore here to silence erroneous unused result warning despite annotating function with @discardableResult
                // Hopefully this bug won't be around for too long...
                _ = self.emulatorCore?.setGameController(controller, at: index)
                controller.addReceiver(self)
            }
            else
            {
                controller.removeReceiver(self)
            }
        }
        
        self.view.setNeedsLayout()
    }
}

//MARK: GameViewControllerDelegate -
/// GameViewControllerDelegate
extension GameViewController: GameViewControllerDelegate
{
    func gameViewController(gameViewController: DeltaCore.GameViewController, handleMenuInputFrom gameController: GameController)
    {
        self.pauseEmulation()
        
        self.performSegue(withIdentifier: "pause", sender: gameController)
    }
    
    func gameViewControllerShouldResumeEmulation(gameViewController: DeltaCore.GameViewController) -> Bool
    {
        return self.pauseViewController == nil
    }
}
