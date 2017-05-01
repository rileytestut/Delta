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

private extension GameViewController
{
    struct PausedSaveState: SaveStateProtocol
    {
        var fileURL: URL
        var gameType: GameType
        
        var isSaved = false
        
        init(fileURL: URL, gameType: GameType)
        {
            self.fileURL = fileURL
            self.gameType = gameType
        }
    }
}

class GameViewController: DeltaCore.GameViewController
{
    /// Assumed to be Delta.Game instance
    override var game: GameProtocol? {
        willSet {
            self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
            
            let game = self.game as? Game
            NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: game?.managedObjectContext)
        }
        didSet {
            self.emulatorCore?.addObserver(self, forKeyPath: #keyPath(EmulatorCore.state), options: [.old], context: &kvoContext)
            
            let game = self.game as? Game
            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.managedObjectContextDidChange(with:)), name: .NSManagedObjectContextObjectsDidChange, object: game?.managedObjectContext)
            
            self.updateControllerSkin()
            self.updateControllers()
        }
    }
    
    //MARK: - Private Properties -
    fileprivate var pauseViewController: PauseViewController?
    fileprivate var pausingGameController: GameController?
    
    // Prevents the same save state from being saved multiple times
    fileprivate var pausedSaveState: PausedSaveState? {
        didSet
        {
            if let saveState = oldValue, self.pausedSaveState == nil
            {
                do
                {
                    try FileManager.default.removeItem(at: saveState.fileURL)
                }
                catch
                {
                    print(error)
                }
            }
        }
    }
    
    fileprivate var _isLoadingSaveState = false
    
    fileprivate var context = CIContext(options: [kCIContextWorkingColorSpace: NSNull()])
    
    // Sustain Buttons
    fileprivate var updateSemaphores = Set<DispatchSemaphore>()
    fileprivate var sustainedInputs = [ObjectIdentifier: [Input]]()
    fileprivate var reactivateSustainedInputsQueue: OperationQueue
    fileprivate var selectingSustainedButtons = false
    
    fileprivate var sustainButtonsContentView: UIView!
    fileprivate var sustainButtonsBlurView: UIVisualEffectView!
    fileprivate var sustainButtonsBackgroundView: RSTPlaceholderView!
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didEnterBackground(with:)), name: .UIApplicationDidEnterBackground, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.settingsDidChange(with:)), name: .settingsDidChange, object: nil)
    }
    
    deinit
    {
        self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
    }
    
    // MARK: - GameControllerReceiver -
    override func gameController(_ gameController: GameController, didActivate input: Input)
    {
        super.gameController(gameController, didActivate: input)
        
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
        
        let gameViewContainerView = self.gameView.superview!
        
        self.sustainButtonsContentView = UIView(frame: CGRect(x: 0, y: 0, width: self.gameView.bounds.width, height: self.gameView.bounds.height))
        self.sustainButtonsContentView.translatesAutoresizingMaskIntoConstraints = false
        self.sustainButtonsContentView.isHidden = true
        self.view.insertSubview(self.sustainButtonsContentView, aboveSubview: gameViewContainerView)
        
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
        
        self.sustainButtonsBackgroundView = RSTPlaceholderView(frame: CGRect(x: 0, y: 0, width: vibrancyView.contentView.bounds.width, height: vibrancyView.contentView.bounds.height))
        self.sustainButtonsBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sustainButtonsBackgroundView.textLabel.text = NSLocalizedString("Select Buttons to Sustain", comment: "")
        self.sustainButtonsBackgroundView.textLabel.numberOfLines = 1
        self.sustainButtonsBackgroundView.textLabel.minimumScaleFactor = 0.5
        self.sustainButtonsBackgroundView.textLabel.adjustsFontSizeToFitWidth = true
        self.sustainButtonsBackgroundView.detailTextLabel.text = NSLocalizedString("Press the Menu button when finished.", comment: "")
        self.sustainButtonsBackgroundView.alpha = 0.0
        vibrancyView.contentView.addSubview(self.sustainButtonsBackgroundView)
        
        // Auto Layout
        self.sustainButtonsContentView.leadingAnchor.constraint(equalTo: gameViewContainerView.leadingAnchor).isActive = true
        self.sustainButtonsContentView.trailingAnchor.constraint(equalTo: gameViewContainerView.trailingAnchor).isActive = true
        self.sustainButtonsContentView.topAnchor.constraint(equalTo: gameViewContainerView.topAnchor).isActive = true
        self.sustainButtonsContentView.bottomAnchor.constraint(equalTo: gameViewContainerView.bottomAnchor).isActive = true
        
        self.updateControllerSkin()
        self.updateControllers()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.updateControllerSkin()
        }, completion: nil)        
    }
    
    // MARK: - Segues
    /// KVO
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showGamesViewController":
            let gamesViewController = (segue.destination as! UINavigationController).topViewController as! GamesViewController
            gamesViewController.theme = .translucent
            gamesViewController.activeEmulatorCore = self.emulatorCore
            
            self.updateAutoSaveState()
            
        case "pause":
            
            if let game = self.game
            {
                let fileURL = FileManager.uniqueTemporaryURL()
                self.pausedSaveState = PausedSaveState(fileURL: fileURL, gameType: game.type)
                
                self.emulatorCore?.saveSaveState(to: fileURL)
            }

            guard let gameController = sender as? GameController else {
                fatalError("sender for pauseSegue must be the game controller that pressed the Menu button")
            }
            
            self.pausingGameController = gameController
            
            let pauseViewController = segue.destination as! PauseViewController
            pauseViewController.pauseText = (self.game as? Game)?.name ?? NSLocalizedString("Delta", comment: "")
            pauseViewController.emulatorCore = self.emulatorCore
            pauseViewController.saveStatesViewControllerDelegate = self
            pauseViewController.cheatsViewControllerDelegate = self
            
            pauseViewController.fastForwardItem?.selected = (self.emulatorCore?.rate != self.emulatorCore?.deltaCore.supportedRates.lowerBound)
            pauseViewController.fastForwardItem?.action = { [unowned self] item in
                guard let emulatorCore = self.emulatorCore else { return }
                emulatorCore.rate = item.selected ? emulatorCore.deltaCore.supportedRates.upperBound : emulatorCore.deltaCore.supportedRates.lowerBound
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
            
            self.pausedSaveState = nil
            
            DispatchQueue.main.async {
                
                if self._isLoadingSaveState
                {
                    // If loading save state, resume emulation immediately (since the game view needs to be updated ASAP)
                    
                    if self.resumeEmulation()
                    {
                        // Temporarily disable audioManager to prevent delayed audio bug when using 3D Touch Peek & Pop
                        self.emulatorCore?.audioManager.isEnabled = false
                        
                        // Re-enable after delay
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.emulatorCore?.audioManager.isEnabled = true
                        }
                    }
                }
                else
                {
                    // Otherwise, wait for the transition to complete before resuming emulation
                    self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                        self.resumeEmulation()
                    })
                }
                
                self._isLoadingSaveState = false
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
        self.pausedSaveState = nil
        self.emulatorCore?.resume()
    }
    
    // MARK: - KVO
    /// KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }
        
        guard let rawValue = change?[.oldKey] as? Int, let previousState = EmulatorCore.State(rawValue: rawValue) else { return }
        
        if previousState == .stopped
        {
            self.emulatorCore?.updateCheats()
        }
    }
}

//MARK: - Controllers -
private extension GameViewController
{
    @objc func updateControllers()
    {
        var controllers = [GameController]()
        controllers.append(self.controllerView)
        
        // We need to map each item as a GameControllerProtocol due to a Swift bug
        controllers.append(contentsOf: ExternalControllerManager.shared.connectedControllers.map { $0 as GameController })
        
        if let index = Settings.localControllerPlayerIndex
        {
            self.controllerView.playerIndex = index
            self.controllerView.isHidden = false
        }
        else
        {
            self.controllerView.playerIndex = nil
            self.controllerView.isHidden = true
        }
        
        // Removing all game controllers from EmulatorCore will reset each controller's playerIndex to nil
        // We temporarily cache their playerIndexes, and then we reset them after removing all controllers
        var controllerIndexes = [ObjectIdentifier: Int?]()
        controllers.forEach { controllerIndexes[ObjectIdentifier($0)] = $0.playerIndex }
        
        self.emulatorCore?.removeAllGameControllers()
        
        // Reset each controller's playerIndex to what it was before removing all controllers from EmulatorCore
        controllers.forEach { $0.playerIndex = controllerIndexes[ObjectIdentifier($0)] ?? nil }
        
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
        self.view.layoutIfNeeded()
    }
    
    func updateControllerSkin()
    {
        guard let game = self.game, let system = System(gameType: game.type) else { return }
        
        let traits = DeltaCore.ControllerSkin.Traits.defaults(for: self.view)
        
        let controllerSkin = Settings.preferredControllerSkin(for: system, traits: traits)
        self.controllerView.controllerSkin = controllerSkin
        
        if controllerSkin?.isTranslucent(for: traits) ?? false
        {
            self.controllerView.alpha = Settings.translucentControllerSkinOpacity
        }
        else
        {
            self.controllerView.alpha = 1.0
        }
    }
}

//MARK: - Save States -
/// Save States
extension GameViewController: SaveStatesViewControllerDelegate
{
    fileprivate func updateAutoSaveState()
    {
        // Ensures game is non-nil and also a Game subclass
        guard let game = self.game as? Game else { return }
        
        // If pausedSaveState exists and has already been saved, don't update auto save state
        // This prevents us from filling our auto save state slots with the same save state
        let savedPausedSaveState = self.pausedSaveState?.isSaved ?? false
        guard !savedPausedSaveState else { return }
        
        self.pausedSaveState?.isSaved = true
        
        // Must be done synchronously
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            
            let game = backgroundContext.object(with: game.objectID) as! Game
            
            let predicate = NSPredicate(format: "%K == %d AND %K == %@", #keyPath(SaveState.type), SaveStateType.auto.rawValue, #keyPath(SaveState.game), game)
            
            let fetchRequest: NSFetchRequest<SaveState> = SaveState.fetchRequest()
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: true)]
            
            var saveStates: [SaveState]? = nil
            
            do
            {
                saveStates = try fetchRequest.execute()
            }
            catch
            {
                print(error)
            }
            
            if let saveStates = saveStates, let saveState = saveStates.first, saveStates.count >= 2
            {
                // If there are two or more auto save states, update the oldest one
                self.update(saveState, with: self.pausedSaveState)
                
                // Tiny hack; SaveStatesViewController sorts save states by creation date, so we update the creation date too
                // Simpler than deleting old save states ¯\_(ツ)_/¯
                saveState.creationDate = saveState.modifiedDate
            }
            else
            {
                // Otherwise, create a new one
                let saveState = SaveState.insertIntoManagedObjectContext(backgroundContext)
                saveState.type = .auto
                saveState.game = game
                
                self.update(saveState, with: self.pausedSaveState)
            }
            
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    fileprivate func update(_ saveState: SaveState, with replacementSaveState: SaveStateProtocol? = nil)
    {
        let isRunning = (self.emulatorCore?.state == .running)
        
        if isRunning
        {
            self.pauseEmulation()
        }
        
        if let replacementSaveState = replacementSaveState
        {
            do
            {
                if FileManager.default.fileExists(atPath: saveState.fileURL.path)
                {
                    // Don't use replaceItem(), since that removes the original file as well
                    try FileManager.default.removeItem(at: saveState.fileURL)
                }
                
                try FileManager.default.copyItem(at: replacementSaveState.fileURL, to: saveState.fileURL)
            }
            catch
            {
                print(error)
            }
        }
        else
        {
            self.emulatorCore?.saveSaveState(to: saveState.fileURL)
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
            catch
            {
                print(error)
            }
        }
        
        saveState.modifiedDate = Date()
        
        if isRunning
        {
            self.resumeEmulation()
        }
    }
    
    //MARK: - SaveStatesViewControllerDelegate
    
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    {
        let updatingExistingSaveState = FileManager.default.fileExists(atPath: saveState.fileURL.path)
        
        self.update(saveState)
        
        // Dismiss if updating an existing save state.
        // If creating a new one, don't dismiss.
        if updatingExistingSaveState
        {
            self.pauseViewController?.dismiss()
        }
    }
    
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateProtocol)
    {
        self._isLoadingSaveState = true
        
        // If we're loading the auto save state, we need to create a temporary copy of saveState.
        // Then, we update the auto save state, but load our copy so everything works out.
        var temporarySaveState: SaveStateProtocol? = nil
        
        if let autoSaveState = saveState as? SaveState, autoSaveState.type == .auto
        {
            let temporaryURL = FileManager.uniqueTemporaryURL()
            
            do
            {
                try FileManager.default.moveItem(at: saveState.fileURL, to: temporaryURL)
                temporarySaveState = DeltaCore.SaveState(fileURL: temporaryURL, gameType: saveState.gameType)
            }
            catch
            {
                print(error)
            }
        }
        
        self.updateAutoSaveState()
        
        do
        {
            if let temporarySaveState = temporarySaveState
            {
                try self.emulatorCore?.load(temporarySaveState)
                try FileManager.default.removeItem(at: temporarySaveState.fileURL)
            }
            else
            {
                try self.emulatorCore?.load(saveState)
            }
        }
        catch EmulatorCore.SaveStateError.doesNotExist
        {
            print("Save State does not exist.")
        }
        catch let error as NSError
        {
            print(error)
        }
        
        // Reactivate sustained inputs
        for gameController in self.emulatorCore?.gameControllers ?? []
        {
            guard let sustainedInputs = self.sustainedInputs[ObjectIdentifier(gameController)] else { continue }
            
            for input in sustainedInputs
            {
                self.reactivateSustainedInput(input, for: gameController)
            }
        }
        
        self.pauseViewController?.dismiss()
    }
}

//MARK: - Cheats -
/// Cheats
extension GameViewController: CheatsViewControllerDelegate
{
    func cheatsViewController(_ cheatsViewController: CheatsViewController, activateCheat cheat: Cheat)
    {
        self.emulatorCore?.activateCheatWithErrorLogging(cheat)
    }
    
    func cheatsViewController(_ cheatsViewController: CheatsViewController, deactivateCheat cheat: Cheat)
    {
        self.emulatorCore?.deactivate(cheat)
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
        
        if let pauseViewController = self.pauseViewController, !self.selectingSustainedButtons
        {
            pauseViewController.dismiss()
        }
        else if self.presentedViewController == nil
        {
            self.pauseEmulation()
            self.performSegue(withIdentifier: "pause", sender: gameController)
        }
    }
    
    func gameViewControllerShouldResumeEmulation(_ gameViewController: DeltaCore.GameViewController) -> Bool
    {
        return (self.presentedViewController == nil || self.presentedViewController?.isDisappearing == true) && !self.selectingSustainedButtons && self.view.window != nil
    }
    
    func gameViewControllerDidUpdate(_ gameViewController: DeltaCore.GameViewController)
    {
        for semaphore in self.updateSemaphores
        {
            semaphore.signal()
        }
    }
}

//MARK: - Notifications -
private extension GameViewController
{
    @objc func didEnterBackground(with notification: Notification)
    {
        self.updateAutoSaveState()
    }
    
    @objc func managedObjectContextDidChange(with notification: Notification)
    {
        guard let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> else { return }
        guard let game = self.game as? Game else { return }
        
        if deletedObjects.contains(game)
        {
            self.emulatorCore?.gameViews.forEach { $0.inputImage = nil }
            self.game = nil
        }
    }
    
    @objc func settingsDidChange(with notification: Notification)
    {
        guard let settingsName = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name else { return }
        
        switch settingsName
        {
        case .localControllerPlayerIndex: self.updateControllers()
            
        case .preferredControllerSkin:
            guard
                let system = notification.userInfo?[Settings.NotificationUserInfoKey.system] as? System,
                let traits = notification.userInfo?[Settings.NotificationUserInfoKey.traits] as? DeltaCore.ControllerSkin.Traits
            else { return }
            
            let currentTraits = DeltaCore.ControllerSkin.Traits.defaults(for: self.view)
            if system.gameType == self.game?.type && traits == currentTraits
            {
                self.updateControllerSkin()
            }
            
        case .translucentControllerSkinOpacity:
            if let traits = self.controllerView.controllerSkinTraits
            {
                if self.controllerView.controllerSkin?.isTranslucent(for: traits) ?? false
                {
                    self.controllerView.alpha = Settings.translucentControllerSkinOpacity
                }
            }
        }
    }
}
