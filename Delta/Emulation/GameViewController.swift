//
//  GameViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

private var kvoContext = 0

class GameViewController: DeltaCore.GameViewController
{
    /// Assumed to be Delta.Game instance
    override var game: GameProtocol? {
        willSet {
            self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
        }
        didSet {
            guard let emulatorCore = self.emulatorCore else { return }
            self.preferredContentSize = emulatorCore.preferredRenderingSize
            
            emulatorCore.addObserver(self, forKeyPath: #keyPath(EmulatorCore.state), options: [.old], context: &kvoContext)
        }
    }
    
    // If non-nil, will override the default preview action items returned in previewActionItems()
    var overridePreviewActionItems: [UIPreviewActionItem]?
    
    //MARK: - Private Properties -
    private var pauseViewController: PauseViewController?
    private var pausingGameController: GameController?
    
    private var context = CIContext(options: [kCIContextWorkingColorSpace: NSNull()])
    
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
    
    deinit
    {
        self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
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
        guard let identifier = segue.identifier, identifier == "pause" else { return }
        
        guard let gameController = sender as? GameController else {
            fatalError("sender for pauseSegue must be the game controller that pressed the Menu button")
        }
        
        self.pausingGameController = gameController
        
        let pauseViewController = segue.destinationViewController as! PauseViewController
        pauseViewController.pauseText = (self.game as? Game)?.name ?? NSLocalizedString("Delta", comment: "")
        pauseViewController.emulatorCore = self.emulatorCore
        pauseViewController.saveStatesViewControllerDelegate = self
        pauseViewController.cheatsViewControllerDelegate = self
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
    
    // MARK: - KVO -
    /// KVO
    override func observeValue(forKeyPath keyPath: String?, of object: AnyObject?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutablePointer<Void>?)
    {
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }
        
        guard let rawValue = change?[.oldKey] as? Int, let previousState = EmulatorCore.State(rawValue: rawValue) else { return }
        
        if previousState == .stopped
        {
            self.updateCheats()
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

//MARK: - Save States
/// Save States
extension GameViewController: SaveStatesViewControllerDelegate
{
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    {
        guard let filepath = saveState.fileURL.path else { return }
        
        var updatingExistingSaveState = true
        
        self.emulatorCore?.save { (temporarySaveState) in
            do
            {
                if FileManager.default.fileExists(atPath: filepath)
                {
                    try FileManager.default.replaceItem(at: saveState.fileURL, withItemAt: temporarySaveState.fileURL, backupItemName: nil, options: [], resultingItemURL: nil)
                }
                else
                {
                    try FileManager.default.moveItem(at: temporarySaveState.fileURL, to: saveState.fileURL)
                    
                    updatingExistingSaveState = false
                }
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        if
            let outputImage = self.gameView.outputImage,
            let quartzImage = self.context.createCGImage(outputImage, from: outputImage.extent),
            let data = UIImagePNGRepresentation(UIImage(cgImage: quartzImage))
        {
            do
            {
                try data.write(to: saveState.imageFileURL, options: [.atomicWrite])
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        saveState.modifiedDate = Date()
        
        // Dismiss if updating an existing save state.
        // If creating a new one, don't dismiss.
        if updatingExistingSaveState
        {
            self.pauseViewController?.dismiss()
        }
    }
    
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateProtocol)
    {
        do
        {
            try self.emulatorCore?.load(saveState)
        }
        catch EmulatorCore.SaveStateError.doesNotExist
        {
            print("Save State does not exist.")
        }
        catch let error as NSError
        {
            print(error)
        }
        
        self.updateCheats()
        
        self.pauseViewController?.dismiss()
    }
}

//MARK: - Cheats
/// Cheats
extension GameViewController: CheatsViewControllerDelegate
{
    func cheatsViewController(_ cheatsViewController: CheatsViewController, activateCheat cheat: Cheat)
    {
        self.activate(cheat)
    }
    
    func cheatsViewController(_ cheatsViewController: CheatsViewController, deactivateCheat cheat: Cheat)
    {
        self.emulatorCore?.deactivate(cheat)
    }
    
    private func activate(_ cheat: Cheat)
    {
        do
        {
            try self.emulatorCore?.activate(cheat)
        }
        catch EmulatorCore.CheatError.invalid
        {
            print("Invalid cheat:", cheat.name, cheat.code)
        }
        catch let error as NSError
        {
            print("Unknown Cheat Error:", error, cheat.name, cheat.code)
        }
    }
    
    private func updateCheats()
    {
        guard let game = self.game as? Game else { return }
        
        let running = (self.emulatorCore?.state == .running)
        
        if running
        {
            // Core MUST be paused when activating cheats, or else race conditions could crash the core
            self.pauseEmulation()
        }
        
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performAndWait {
            
            let predicate = Predicate(format: "%K == %@", Cheat.Attributes.game.rawValue, game)
            
            let cheats = Cheat.instancesWithPredicate(predicate, inManagedObjectContext: backgroundContext, type: Cheat.self)
            for cheat in cheats
            {
                if cheat.enabled
                {
                    self.activate(cheat)
                }
                else
                {
                    self.emulatorCore?.deactivate(cheat)
                }
            }
        }
        
        if running
        {
            self.resumeEmulation()
        }
        
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
