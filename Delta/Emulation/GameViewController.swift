//
//  GameViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import Roxas

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
    
    // Sustain Buttons
    private var updateSemaphores = Set<DispatchSemaphore>()
    private var sustainedInputs = [ObjectIdentifier: [Input]]()
    private var reactivateSustainedInputsQueue: OperationQueue
    private var selectingSustainedButtons = false
    
    private var sustainButtonsContentView: UIView!
    private var sustainButtonsBlurView: UIVisualEffectView!
    private var sustainButtonsBackgroundView: RSTBackgroundView!
    
    override var previewActionItems: [UIPreviewActionItem]
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
    
    required init()
    {
        self.reactivateSustainedInputsQueue = OperationQueue()
        self.reactivateSustainedInputsQueue.maxConcurrentOperationCount = 1
        
        super.init()
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        self.reactivateSustainedInputsQueue = OperationQueue()
        self.reactivateSustainedInputsQueue.maxConcurrentOperationCount = 1
        
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
    
    // MARK: - GameControllerReceiver -
    override func gameController(_ gameController: GameController, didActivate input: Input)
    {
        super.gameController(gameController, didActivate: input)
        
        if gameController is ControllerView && UIDevice.current.isVibrationSupported
        {
            UIDevice.current.vibrate()
        }
        
        guard (input as? ControllerInput) != .menu else { return }
        
        if self.selectingSustainedButtons
        {
            self.addSustainedInput(input, for: gameController)
        }
        else if let sustainedInputs = self.sustainedInputs[ObjectIdentifier(gameController)], sustainedInputs.contains(where: { $0.isEqual(input) })
        {
            // Perform on next run loop
            DispatchQueue.main.async {
                self.reactivateSustainedInput(input, for: gameController)
            }
        }
    }
}


//MARK: - UIViewController -
/// UIViewController
extension GameViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.sustainButtonsContentView = UIView(frame: CGRect(x: 0, y: 0, width: self.gameView.bounds.width, height: self.gameView.bounds.height))
        self.sustainButtonsContentView.translatesAutoresizingMaskIntoConstraints = false
        self.sustainButtonsContentView.isHidden = true
        self.view.insertSubview(self.sustainButtonsContentView, aboveSubview: self.gameView)
        
        let blurEffect = UIBlurEffect(style: .dark)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        
        self.sustainButtonsBlurView = UIVisualEffectView(effect: blurEffect)
        self.sustainButtonsBlurView.frame = CGRect(x: 0, y: 0, width: self.sustainButtonsContentView.bounds.width, height: self.sustainButtonsContentView.bounds.height)
        self.sustainButtonsBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sustainButtonsContentView.addSubview(self.sustainButtonsBlurView)
        
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = CGRect(x: 0, y: 0, width: self.sustainButtonsBlurView.contentView.bounds.width, height: self.sustainButtonsBlurView.contentView.bounds.height)
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sustainButtonsBlurView.contentView.addSubview(vibrancyView)
        
        self.sustainButtonsBackgroundView = RSTBackgroundView(frame: CGRect(x: 0, y: 0, width: vibrancyView.contentView.bounds.width, height: vibrancyView.contentView.bounds.height))
        self.sustainButtonsBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sustainButtonsBackgroundView.textLabel.text = NSLocalizedString("Select Buttons to Sustain", comment: "")
        self.sustainButtonsBackgroundView.textLabel.numberOfLines = 1
        self.sustainButtonsBackgroundView.textLabel.minimumScaleFactor = 0.5
        self.sustainButtonsBackgroundView.textLabel.adjustsFontSizeToFitWidth = true
        self.sustainButtonsBackgroundView.detailTextLabel.text = NSLocalizedString("Press the Menu button when finished.", comment: "")
        self.sustainButtonsBackgroundView.alpha = 0.0
        vibrancyView.contentView.addSubview(self.sustainButtonsBackgroundView)
        
        // Auto Layout
        self.sustainButtonsContentView.leadingAnchor.constraint(equalTo: self.gameView.leadingAnchor).isActive = true
        self.sustainButtonsContentView.trailingAnchor.constraint(equalTo: self.gameView.trailingAnchor).isActive = true
        self.sustainButtonsContentView.topAnchor.constraint(equalTo: self.gameView.topAnchor).isActive = true
        self.sustainButtonsContentView.bottomAnchor.constraint(equalTo: self.gameView.bottomAnchor).isActive = true
        
        self.updateControllers()
    }
    
    // MARK: - Segues
    /// KVO
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showGamesViewController":
            let gamesViewController = (segue.destination as! UINavigationController).topViewController as! GamesViewController
            gamesViewController.theme = .dark
            
        case "pause":
            guard let gameController = sender as? GameController else {
                fatalError("sender for pauseSegue must be the game controller that pressed the Menu button")
            }
            
            self.pausingGameController = gameController
            
            let pauseViewController = segue.destination as! PauseViewController
            pauseViewController.pauseText = (self.game as? Game)?.name ?? NSLocalizedString("Delta", comment: "")
            pauseViewController.emulatorCore = self.emulatorCore
            pauseViewController.saveStatesViewControllerDelegate = self
            pauseViewController.cheatsViewControllerDelegate = self
            
            pauseViewController.fastForwardItem?.selected = (self.emulatorCore?.rate != self.emulatorCore?.configuration.supportedRates.lowerBound)
            pauseViewController.fastForwardItem?.action = { [unowned self] item in
                guard let emulatorCore = self.emulatorCore else { return }
                emulatorCore.rate = item.selected ? emulatorCore.configuration.supportedRates.upperBound : emulatorCore.configuration.supportedRates.lowerBound
            }
            
            pauseViewController.sustainButtonsItem?.selected = (self.sustainedInputs[ObjectIdentifier(gameController)]?.count ?? 0) > 0
            pauseViewController.sustainButtonsItem?.action = { [unowned self, unowned pauseViewController] item in
                
                self.resetSustainedInputs(for: gameController)
                
                if item.selected
                {
                    self.showSustainButtonView()
                    pauseViewController.dismiss()
                }
            }
            
            self.pauseViewController = pauseViewController
            
        default: break
        }
    }
    
    @IBAction private func unwindFromPauseViewController(_ segue: UIStoryboardSegue)
    {
        self.pauseViewController = nil
        self.pausingGameController = nil
        
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "unwindFromPauseMenu":
            DispatchQueue.main.async {
                if
                    let transitionCoordinator = self.transitionCoordinator,
                    let navigationController = segue.source.navigationController,
                    navigationController.viewControllers.count == 1
                {
                    // If user pressed "Resume" from Pause Menu, we wait for the transition to complete before resuming emulation
                    transitionCoordinator.animate(alongsideTransition: nil, completion: { (context) in
                        self.resumeEmulation()
                    })
                }
                else
                {
                    // Otherwise, we resume emulation immediately (such as when loading save states and the game view needs to be updated ASAP)
                    
                    if self.resumeEmulation()
                    {
                        // Temporarily disable audioManager to prevent delayed audio bug when using 3D Touch Peek & Pop
                        self.emulatorCore?.audioManager.enabled = false
                        
                        // Re-enable after delay
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.emulatorCore?.audioManager.enabled = true
                        }
                    }
                }
            }
            
        case "unwindToGames":
            DispatchQueue.main.async {
                self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                    self.performSegue(withIdentifier: "showGamesViewController", sender: nil)
                })
            }
            
        default: break
        }
    }
    
    @IBAction private func unwindFromGamesViewController(with segue: UIStoryboardSegue)
    {
        self.emulatorCore?.resume()
    }
    
    // MARK: - KVO
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

//MARK: - Controllers -
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

//MARK: - Save States -
/// Save States
extension GameViewController: SaveStatesViewControllerDelegate
{
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    {
        var updatingExistingSaveState = true
        
        self.emulatorCore?.save { (temporarySaveState) in
            do
            {
                if FileManager.default.fileExists(atPath: saveState.fileURL.path)
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

//MARK: - Cheats -
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
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            
            let predicate = NSPredicate(format: "%K == %@", Cheat.Attributes.game.rawValue, game)
            
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

//MARK: - Sustain Buttons -
private extension GameViewController
{
    func showSustainButtonView()
    {
        self.selectingSustainedButtons = true
        
        let blurEffect = self.sustainButtonsBlurView.effect
        self.sustainButtonsBlurView.effect = nil
        
        self.sustainButtonsContentView.isHidden = false
        
        UIView.animate(withDuration: 0.4) {
            self.sustainButtonsBlurView.effect = blurEffect
            self.sustainButtonsBackgroundView.alpha = 1.0
        }
    }
    
    func hideSustainButtonView()
    {
        self.selectingSustainedButtons = false
        
        let blurEffect = self.sustainButtonsBlurView.effect
        
        UIView.animate(withDuration: 0.4, animations: {
            self.sustainButtonsBlurView.effect = nil
            self.sustainButtonsBackgroundView.alpha = 0.0
        }) { (finished) in
            self.sustainButtonsContentView.isHidden = true
            self.sustainButtonsBlurView.effect = blurEffect
        }
    }
    
    func resetSustainedInputs(for gameController: GameController)
    {
        if let previousInputs = self.sustainedInputs[ObjectIdentifier(gameController)]
        {
            let receivers = gameController.receivers
            receivers.forEach { gameController.removeReceiver($0) }
            
            // Activate previousInputs without notifying anyone so we can then deactivate them
            // We do this because deactivating an already deactivated input has no effect
            previousInputs.forEach { gameController.activate($0) }
            
            receivers.forEach { gameController.addReceiver($0) }
            
            // Deactivate previously sustained inputs
            previousInputs.forEach { gameController.deactivate($0) }
        }
        
        self.sustainedInputs[ObjectIdentifier(gameController)] = []
    }
    
    func addSustainedInput(_ input: Input, for gameController: GameController)
    {
        var inputs = self.sustainedInputs[ObjectIdentifier(gameController)] ?? []
        
        guard !inputs.contains(where: { $0.isEqual(input) }) else { return }
        
        inputs.append(input)
        self.sustainedInputs[ObjectIdentifier(gameController)] = inputs
        
        let receivers = gameController.receivers
        receivers.forEach { gameController.removeReceiver($0) }
        
        // Causes input to be considered deactivated, so gameController won't send a subsequent message to observers when user actually deactivates
        // However, at this point the core still thinks it is activated, and is temporarily not a receiver, thus sustaining it
        gameController.deactivate(input)
        
        receivers.forEach { gameController.addReceiver($0) }
    }
    
    func reactivateSustainedInput(_ input: Input, for gameController: GameController)
    {
        // These MUST be performed serially, or else Bad Things Happen™ if multiple inputs are reactivated at once
        self.reactivateSustainedInputsQueue.addOperation {
            
            // The manual activations/deactivations here are hidden implementation details, so we won't notify ourselves about them
            gameController.removeReceiver(self)
            
            // Must deactivate first so core recognizes a secondary activation
            gameController.deactivate(input)
            
            let dispatchQueue = DispatchQueue(label: "com.rileytestut.Delta.sustainButtonsQueue")
            dispatchQueue.async {
                
                let semaphore = DispatchSemaphore(value: 0)
                self.updateSemaphores.insert(semaphore)
                
                // To ensure the emulator core recognizes us activating the input again, we need to wait at least two frames
                // Unfortunately we cannot init DispatchSemaphore with value less than 0
                // To compensate, we simply wait twice; once the first wait returns, we wait again
                semaphore.wait()
                semaphore.wait()
                
                // These MUST be performed serially, or else Bad Things Happen™ if multiple inputs are reactivated at once
                self.reactivateSustainedInputsQueue.addOperation {
                    
                    self.updateSemaphores.remove(semaphore)
                    
                    // Ensure we still are not a receiver (to prevent rare race conditions)
                    gameController.removeReceiver(self)
                    
                    gameController.activate(input)
                    
                    let receivers = gameController.receivers
                    receivers.forEach { gameController.removeReceiver($0) }
                    
                    // Causes input to be considered deactivated, so gameController won't send a subsequent message to observers when user actually deactivates
                    // However, at this point the core still thinks it is activated, and is temporarily not a receiver, thus sustaining it
                    gameController.deactivate(input)
                    
                    receivers.forEach { gameController.addReceiver($0) }
                }
                
                // More Bad Things Happen™ if we add self as observer before ALL reactivations have occurred (notable, infinite loops)
                self.reactivateSustainedInputsQueue.waitUntilAllOperationsAreFinished()
                
                gameController.addReceiver(self)
            }
        }
    }
}

//MARK: - GameViewControllerDelegate -
/// GameViewControllerDelegate
extension GameViewController: GameViewControllerDelegate
{
    func gameViewController(_ gameViewController: DeltaCore.GameViewController, handleMenuInputFrom gameController: GameController)
    {
        if self.selectingSustainedButtons
        {
            self.hideSustainButtonView()
        }
        
        self.pauseEmulation()
        self.performSegue(withIdentifier: "pause", sender: gameController)
    }
    
    func gameViewControllerShouldResumeEmulation(_ gameViewController: DeltaCore.GameViewController) -> Bool
    {
        return (self.presentedViewController == nil || self.presentedViewController?.isDisappearing == true) && !self.selectingSustainedButtons
    }
    
    func gameViewControllerDidUpdate(_ gameViewController: DeltaCore.GameViewController)
    {
        for semaphore in self.updateSemaphores
        {
            semaphore.signal()
        }
    }
}
