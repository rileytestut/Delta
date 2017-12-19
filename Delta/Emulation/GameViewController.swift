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
    
    struct SustainInputsMapping: GameControllerInputMappingProtocol
    {
        let gameController: GameController
        
        var gameControllerInputType: GameControllerInputType {
            return self.gameController.inputType
        }
        
        func input(forControllerInput controllerInput: Input) -> Input?
        {
            if let mappedInput = self.gameController.defaultInputMapping?.input(forControllerInput: controllerInput), mappedInput == StandardGameControllerInput.menu
            {
                return mappedInput
            }
            
            return controllerInput
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
    private var pauseViewController: PauseViewController?
    private var pausingGameController: GameController?
    
    // Prevents the same save state from being saved multiple times
    private var pausedSaveState: PausedSaveState? {
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
    
    private var _isLoadingSaveState = false
    
    private var context = CIContext(options: [kCIContextWorkingColorSpace: NSNull()])
    
    // Sustain Buttons
    private var isSelectingSustainedButtons = false
    private var sustainInputsMapping: SustainInputsMapping?
    
    private var sustainButtonsContentView: UIView!
    private var sustainButtonsBlurView: UIVisualEffectView!
    private var sustainButtonsBackgroundView: RSTPlaceholderView!
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateControllers), name: .externalGameControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateControllers), name: .externalGameControllerDidDisconnect, object: nil)
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
        
        if self.isSelectingSustainedButtons
        {
            guard let pausingGameController = self.pausingGameController, gameController == pausingGameController else { return }
            
            if input != StandardGameControllerInput.menu
            {
                gameController.sustain(input)
            }
        }
        else if self.emulatorCore?.state == .running
        {
            guard let actionInput = ActionInput(input: input) else { return }
            
            switch actionInput
            {
            case .quickSave: self.performQuickSaveAction()
            case .quickLoad: self.performQuickLoadAction()
            case .fastForward: self.performFastForwardAction(activate: true)
            }
        }
    }
    
    override func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        super.gameController(gameController, didDeactivate: input)
        
        guard !self.isSelectingSustainedButtons else { return }
        
        guard let actionInput = ActionInput(input: input) else { return }
        
        switch actionInput
        {
        case .quickSave: break
        case .quickLoad: break
        case .fastForward: self.performFastForwardAction(activate: false)
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
        
        // Lays out self.gameView, so we can pin self.sustainButtonsContentView to it without resulting in a temporary "cannot satisfy constraints".
        self.view.layoutIfNeeded()
        
        let gameViewContainerView = self.gameView.superview!
        
        self.controllerView.translucentControllerSkinOpacity = Settings.translucentControllerSkinOpacity
        
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
                let fileURL = FileManager.default.uniqueTemporaryURL()
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
            
            pauseViewController.fastForwardItem?.isSelected = (self.emulatorCore?.rate != self.emulatorCore?.deltaCore.supportedRates.lowerBound)
            pauseViewController.fastForwardItem?.action = { [unowned self] item in
                self.performFastForwardAction(activate: item.isSelected)
            }
            
            pauseViewController.sustainButtonsItem?.isSelected = gameController.sustainedInputs.count > 0
            pauseViewController.sustainButtonsItem?.action = { [unowned self, unowned pauseViewController] item in
                
                for input in gameController.sustainedInputs
                {
                    gameController.unsustain(input)
                }
                
                if item.isSelected
                {
                    self.showSustainButtonView()
                    pauseViewController.dismiss()
                }
                
                // Re-set gameController as pausingGameController.
                self.pausingGameController = gameController
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
        let isExternalGameControllerConnected = ExternalGameControllerManager.shared.connectedControllers.contains(where: { $0.playerIndex != nil })
        if !isExternalGameControllerConnected && Settings.localControllerPlayerIndex == nil
        {
            Settings.localControllerPlayerIndex = 0
        }
        
        // If Settings.localControllerPlayerIndex is non-nil, and there isn't a connected controller with same playerIndex, show controller view.
        if let index = Settings.localControllerPlayerIndex, !ExternalGameControllerManager.shared.connectedControllers.contains { $0.playerIndex == index }
        {
            self.controllerView.playerIndex = index
            self.controllerView.isHidden = false
        }
        else
        {
            self.controllerView.playerIndex = nil
            self.controllerView.isHidden = true
            
            Settings.localControllerPlayerIndex = nil
        }
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        
        if let emulatorCore = self.emulatorCore, let game = self.game
        {
            let controllers = [self.controllerView as GameController] + ExternalGameControllerManager.shared.connectedControllers
            
            for gameController in controllers
            {
                if gameController.playerIndex != nil
                {
                    if let inputMapping = GameControllerInputMapping.inputMapping(for: gameController, gameType: game.type, in: DatabaseManager.shared.viewContext)
                    {
                        gameController.addReceiver(self, inputMapping: inputMapping)
                        gameController.addReceiver(emulatorCore, inputMapping: inputMapping)
                    }
                    else
                    {
                        gameController.addReceiver(self)
                        gameController.addReceiver(emulatorCore)
                    }
                }
                else
                {
                    gameController.removeReceiver(self)
                    gameController.removeReceiver(emulatorCore)
                }
            }
        }        
    }
    
    func updateControllerSkin()
    {
        guard let game = self.game, let system = System(gameType: game.type) else { return }
        
        let traits = DeltaCore.ControllerSkin.Traits.defaults(for: self.view)
        
        let controllerSkin = Settings.preferredControllerSkin(for: system, traits: traits)
        self.controllerView.controllerSkin = controllerSkin
    }
}

//MARK: - Save States -
/// Save States
extension GameViewController: SaveStatesViewControllerDelegate
{
    private func updateAutoSaveState()
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
            
            let fetchRequest = SaveState.fetchRequest(for: game, type: .auto)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: true)]
            
            do
            {
                let saveStates = try fetchRequest.execute()
                
                if let saveState = saveStates.first, saveStates.count >= 2
                {
                    // If there are two or more auto save states, update the oldest one
                    self.update(saveState, with: self.pausedSaveState)
                    
                    // Tiny hack: SaveStatesViewController sorts save states by creation date, so we update the creation date too
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
            }
            catch
            {
                print(error)
            }

            backgroundContext.saveWithErrorLogging()
        }
    }
    
    private func update(_ saveState: SaveState, with replacementSaveState: SaveStateProtocol? = nil)
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
    
    private func load(_ saveState: SaveStateProtocol)
    {
        let isRunning = (self.emulatorCore?.state == .running)
        
        if isRunning
        {
            self.pauseEmulation()
        }
        
        // If we're loading the auto save state, we need to create a temporary copy of saveState.
        // Then, we update the auto save state, but load our copy so everything works out.
        var temporarySaveState: SaveStateProtocol? = nil
        
        if let autoSaveState = saveState as? SaveState, autoSaveState.type == .auto
        {
            let temporaryURL = FileManager.default.uniqueTemporaryURL()
            
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
        
        self.load(saveState)
        
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
        guard let gameController = self.pausingGameController else { return }
        
        self.isSelectingSustainedButtons = true
        
        let sustainInputsMapping = SustainInputsMapping(gameController: gameController)
        gameController.addReceiver(self, inputMapping: sustainInputsMapping)
        
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
        guard let gameController = self.pausingGameController else { return }
        
        self.isSelectingSustainedButtons = false
        
        self.updateControllers()
        self.sustainInputsMapping = nil
        
        // Reactivate all sustained inputs, since they will now be mapped to game inputs.
        for input in gameController.sustainedInputs
        {
            gameController.activate(input)
        }
        
        let blurEffect = self.sustainButtonsBlurView.effect
        
        UIView.animate(withDuration: 0.4, animations: {
            self.sustainButtonsBlurView.effect = nil
            self.sustainButtonsBackgroundView.alpha = 0.0
        }) { (finished) in
            self.sustainButtonsContentView.isHidden = true
            self.sustainButtonsBlurView.effect = blurEffect
        }
    }
}

//MARK: - Action Inputs -
/// Action Inputs
extension GameViewController
{
    func performQuickSaveAction()
    {
        guard let game = self.game as? Game else { return }
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            
            let game = backgroundContext.object(with: game.objectID) as! Game
            let fetchRequest = SaveState.fetchRequest(for: game, type: .quick)
            
            do
            {
                if let quickSaveState = try fetchRequest.execute().first
                {
                    self.update(quickSaveState)
                }
                else
                {
                    let saveState = SaveState(context: backgroundContext)
                    saveState.type = .quick
                    saveState.game = game
                    
                    self.update(saveState)
                }
            }
            catch
            {
                print(error)
            }
            
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    func performQuickLoadAction()
    {
        guard let game = self.game as? Game else { return }
        
        let fetchRequest = SaveState.fetchRequest(for: game, type: .quick)
        
        do
        {
            if let quickSaveState = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
            {
                self.load(quickSaveState)
            }
        }
        catch
        {
            print(error)
        }
    }
    
    func performFastForwardAction(activate: Bool)
    {
        guard let emulatorCore = self.emulatorCore else { return }
        
        if activate
        {
            emulatorCore.rate = emulatorCore.deltaCore.supportedRates.upperBound
        }
        else
        {
            emulatorCore.rate = emulatorCore.deltaCore.supportedRates.lowerBound
        }
    }
}

//MARK: - GameViewControllerDelegate -
/// GameViewControllerDelegate
extension GameViewController: GameViewControllerDelegate
{
    func gameViewController(_ gameViewController: DeltaCore.GameViewController, handleMenuInputFrom gameController: GameController)
    {
        if let pausingGameController = self.pausingGameController
        {
            guard pausingGameController == gameController else { return }
        }
        
        if self.isSelectingSustainedButtons
        {
            self.hideSustainButtonView()
        }
        
        if let pauseViewController = self.pauseViewController, !self.isSelectingSustainedButtons
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
        return (self.presentedViewController == nil || self.presentedViewController?.isDisappearing == true) && !self.isSelectingSustainedButtons && self.view.window != nil
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
            
        case .translucentControllerSkinOpacity: self.controllerView.translucentControllerSkinOpacity = Settings.translucentControllerSkinOpacity
        }
    }
}
