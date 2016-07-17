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
    override var game: GameProtocol? {
        didSet {
            guard let emulatorCore = self.emulatorCore else { return }
            self.preferredContentSize = emulatorCore.preferredRenderingSize
        }
    }
    
    // If non-nil, will override the default preview action items returned in previewActionItems()
    var overridePreviewActionItems: [UIPreviewActionItem]?
    
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
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
            self.resumeEmulation()
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Stop Emulation", comment: ""), style: .destructive, handler: { (action) in
            self.dismiss(animated: true)
        }))
        self.present(alertController, animated: true)
    }
}
