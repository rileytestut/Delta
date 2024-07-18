//
//  GameViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import Photos

import DeltaCore
import GBADeltaCore
import MelonDSDeltaCore
import Systems

import struct DSDeltaCore.DS

import Roxas
import AltKit

private var kvoContext = 0

private extension DeltaCore.ControllerSkin
{
    func hasTouchScreen(for traits: DeltaCore.ControllerSkin.Traits) -> Bool
    {
        let hasTouchScreen = self.items(for: traits)?.contains(where: { $0.kind == .touchScreen }) ?? false
        return hasTouchScreen
    }
}

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
    
    struct DefaultInputMapping: GameControllerInputMappingProtocol
    {
        let gameController: GameController
        
        var gameControllerInputType: GameControllerInputType {
            return self.gameController.inputType
        }
        
        func input(forControllerInput controllerInput: Input) -> Input?
        {
            if let mappedInput = self.gameController.defaultInputMapping?.input(forControllerInput: controllerInput)
            {
                return mappedInput
            }
            
            // Only intercept controller skin inputs.
            guard controllerInput.type == .controller(.controllerSkin) else { return nil }
            
            let actionInput = ActionInput(stringValue: controllerInput.stringValue)
            return actionInput
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
            
            self.emulatorCore?.saveHandler = { [weak self] _ in self?.updateGameSave() }
            
            if oldValue?.fileURL != game?.fileURL
            {
                self.shouldResetSustainedInputs = true
            }
            
            self.updateControllers()
            self.updateAudio()
            
            self.presentedGyroAlert = false
        }
    }
    
    private var isGameScene: Bool {
        let gameScene = self.view.window?.windowScene as? GameScene
        return gameScene != nil
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
    
    private var _deepLinkResumingSaveState: SaveStateProtocol? {
        didSet {
            guard let saveState = oldValue, _deepLinkResumingSaveState == nil else { return }
            
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
    
    private var _isLoadingSaveState = false
    
    // Handoff
    private var isContinuingHandoff = false
    private var handoffPlaceholderView: RSTPlaceholderView!
    
    // Gestures
    private var isMenuButtonHeldDown = false
    private var ignoreNextMenuInput = false
    private lazy var menuButtonGestureRecognizers = self.makeMenuButtonGestureRecognizers()
    private lazy var menuButtonKeyboardGestureRecognizers = self.makeMenuButtonGestureRecognizers()
        
    // Sustain Buttons
    private var isSelectingSustainedButtons = false
    private var sustainInputsMapping: SustainInputsMapping?
    private var shouldResetSustainedInputs = false
    
    private var sustainButtonsContentView: UIView!
    private var sustainButtonsBlurView: UIVisualEffectView!
    private var sustainButtonsBackgroundView: RSTPlaceholderView!
    private var inputsToSustain = [AnyInput: Double]()
    
    private var isGyroActive = false
    private var presentedGyroAlert = false
    
    private var presentedJITAlert = false
    
    override var shouldAutorotate: Bool {
        return !self.isGyroActive
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard self.isGyroActive else { return super.supportedInterfaceOrientations }
        
        // Lock orientation to whatever current device orientation is.
        
        switch UIDevice.current.orientation
        {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
            
        // UIDevice.landscapeLeft == UIInterfaceOrientation.landscapeRight (and vice versa)
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
            
        default: return super.supportedInterfaceOrientations
        }
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    override var prefersStatusBarHidden: Bool {
        return !ExperimentalFeatures.shared.showStatusBar.isEnabled
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didEnterBackground(with:)), name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.settingsDidChange(with:)), name: Settings.didChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.deepLinkControllerWillLaunchGame(with:)), name: .deepLinkControllerWillLaunchGame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.deepLinkControllerLaunchGame(with:)), name: .deepLinkControllerLaunchGame, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didActivateGyro(with:)), name: GBA.didActivateGyroNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didDeactivateGyro(with:)), name: GBA.didDeactivateGyroNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.emulationDidQuit(with:)), name: EmulatorCore.emulationDidQuitNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didEnableJIT(with:)), name: ServerManager.didEnableJITNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneWillConnect(with:)), name: UIScene.willConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneDidDisconnect(with:)), name: UIScene.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneSessionWillQuit(with:)), name: UISceneSession.willQuitNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneKeyboardFocusDidChange(with:)), name: UIScene.keyboardFocusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardDidShow(with:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardDidChangeFrame(with:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        
        self.automaticallyPausesWhileInactive = Settings.pauseWhileInactive
    }
    
    deinit
    {
        self.emulatorCore?.removeObserver(self, forKeyPath: #keyPath(EmulatorCore.state), context: &kvoContext)
    }
    
    // MARK: - GameControllerReceiver -
    override func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        super.gameController(gameController, didActivate: input, value: value)
        
        // Ignore unless we're the active scene.
        guard self.view.window?.windowScene?.hasKeyboardFocus == true else { return }
        
        if self.isSelectingSustainedButtons
        {
            guard let pausingGameController = self.pausingGameController, gameController == pausingGameController else { return }
            
            if input != StandardGameControllerInput.menu
            {
                self.inputsToSustain[AnyInput(input)] = value
            }
        }
        else if let standardInput = StandardGameControllerInput(input: input), standardInput == .menu, input.type == .controller(.controllerSkin)
        {
            self.isMenuButtonHeldDown = true
            
            let sustainInputsMapping = SustainInputsMapping(gameController: gameController)
            gameController.addReceiver(self, inputMapping: sustainInputsMapping)
        }
        else if let actionInput = ActionInput(input: input), let emulatorCore = self.emulatorCore, emulatorCore.state == .running
        {
            switch actionInput
            {
            case .quickSave: self.performQuickSaveAction()
            case .quickLoad: self.performQuickLoadAction()
            case .fastForward: self.performFastForwardAction(activate: true)
            case .reverseScreens: self.performReverseScreensAction()
            case .toggleFastForward:
                let isFastForwarding = (emulatorCore.rate != emulatorCore.deltaCore.supportedRates.lowerBound)
                self.performFastForwardAction(activate: !isFastForwarding)
            }
        }
        else if self.isMenuButtonHeldDown
        {
            self.ignoreNextMenuInput = true
            
            if gameController.sustainedInputs.keys.contains(AnyInput(input))
            {
                DispatchQueue.main.async {
                    gameController.unsustain(input)
                }
            }
            else
            {                
                gameController.sustain(input, value: value)
            }
        }
    }
    
    override func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        super.gameController(gameController, didDeactivate: input)
        
        // Ignore unless we're the active scene.
        guard self.view.window?.windowScene?.hasKeyboardFocus == true else { return }
        
        if self.isSelectingSustainedButtons
        {
            if input.isContinuous
            {
                self.inputsToSustain[AnyInput(input)] = nil
            }
        }
        else if let standardInput = StandardGameControllerInput(input: input), standardInput == .menu, input.type == .controller(.controllerSkin)
        {
            self.isMenuButtonHeldDown = false
            
            // Reset controller mapping back to what it should be.
            self.updateControllers()
        }
        else if let actionInput = ActionInput(input: input)
        {
            switch actionInput
            {
            case .quickSave: break
            case .quickLoad: break
            case .fastForward: self.performFastForwardAction(activate: false)
            case .toggleFastForward: break
            case .reverseScreens: break
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
        
        // Lays out self.gameView, so we can pin self.sustainButtonsContentView to it without resulting in a temporary "cannot satisfy constraints".
        self.view.layoutIfNeeded()
        
        self.controllerView.translucentControllerSkinOpacity = Settings.translucentControllerSkinOpacity
        
        // Sustain Button
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
        
        self.sustainButtonsBackgroundView = RSTPlaceholderView(frame: CGRect(x: 0, y: 0, width: vibrancyView.contentView.bounds.width, height: vibrancyView.contentView.bounds.height))
        self.sustainButtonsBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sustainButtonsBackgroundView.textLabel.text = NSLocalizedString("Select Buttons to Hold Down", comment: "")
        self.sustainButtonsBackgroundView.textLabel.numberOfLines = 1
        self.sustainButtonsBackgroundView.textLabel.minimumScaleFactor = 0.5
        self.sustainButtonsBackgroundView.textLabel.adjustsFontSizeToFitWidth = true
        self.sustainButtonsBackgroundView.detailTextLabel.text = NSLocalizedString("Press the Menu button when finished.", comment: "")
        self.sustainButtonsBackgroundView.alpha = 0.0
        vibrancyView.contentView.addSubview(self.sustainButtonsBackgroundView)
        
        // Handoff
        self.handoffPlaceholderView = RSTPlaceholderView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        self.handoffPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        self.handoffPlaceholderView.isHidden = true
        self.handoffPlaceholderView.textLabel.isHidden = true
        self.handoffPlaceholderView.detailTextLabel.font = UIFont.preferredFont(forTextStyle: .body)
        self.handoffPlaceholderView.detailTextLabel.text = NSLocalizedString("Resuming…", comment: "")
        self.handoffPlaceholderView.detailTextLabel.numberOfLines = 1
        self.handoffPlaceholderView.detailTextLabel.minimumScaleFactor = 0.5
        self.handoffPlaceholderView.detailTextLabel.adjustsFontSizeToFitWidth = true
        self.handoffPlaceholderView.activityIndicatorView.isHidden = false
        self.handoffPlaceholderView.activityIndicatorView.startAnimating()
        self.handoffPlaceholderView.activityIndicatorView.color = .white
        self.view.insertSubview(self.handoffPlaceholderView, aboveSubview: self.gameView)
        
        // Gestures
        for gestureRecognizer in self.menuButtonGestureRecognizers
        {
            self.view.addGestureRecognizer(gestureRecognizer)
        }
        
        // Auto Layout
        NSLayoutConstraint.activate([
            self.sustainButtonsContentView.leadingAnchor.constraint(equalTo: self.gameView.leadingAnchor),
            self.sustainButtonsContentView.trailingAnchor.constraint(equalTo: self.gameView.trailingAnchor),
            self.sustainButtonsContentView.topAnchor.constraint(equalTo: self.gameView.topAnchor),
            self.sustainButtonsContentView.bottomAnchor.constraint(equalTo: self.gameView.bottomAnchor),
            
            self.handoffPlaceholderView.leadingAnchor.constraint(equalTo: self.gameView.leadingAnchor),
            self.handoffPlaceholderView.trailingAnchor.constraint(equalTo: self.gameView.trailingAnchor),
            self.handoffPlaceholderView.topAnchor.constraint(equalTo: self.gameView.topAnchor),
            self.handoffPlaceholderView.bottomAnchor.constraint(equalTo: self.gameView.bottomAnchor),
        ])
        
        self.updateControllers()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if self.emulatorCore?.deltaCore == DS.core, UserDefaults.standard.desmumeDeprecatedAlertCount < 3
        {
            let toastView = RSTToastView(text: NSLocalizedString("DeSmuME Core Deprecated", comment: ""), detailText: NSLocalizedString("Switch to the melonDS core in Settings for latest improvements.", comment: ""))
            self.show(toastView, duration: 5.0)
            
            UserDefaults.standard.desmumeDeprecatedAlertCount += 1
        }
        else if self.emulatorCore?.deltaCore == MelonDS.core, ProcessInfo.processInfo.isJITAvailable
        {
            self.showJITEnabledAlert()
        }
        
        self.startGameActivity()
        
        if let scene = UIApplication.shared.externalDisplayScene, Settings.supportsExternalDisplays
        {
            // We have priority, so replace whatever is currently on external display.
            self.connectExternalDisplay(for: scene)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard UIApplication.shared.applicationState != .background else { return }
                
        coordinator.animate(alongsideTransition: { (context) in
            self.updateControllerSkin()
        }, completion: nil)        
    }
    
    // MARK: - Segues
    /// KVO
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        self.pauseGameActivity()
        
        switch identifier
        {
        case "showGamesViewController":
            let gamesViewController = (segue.destination as! UINavigationController).topViewController as! GamesViewController
            
            if let emulatorCore = self.emulatorCore
            {
                gamesViewController.theme = .translucent
                gamesViewController.activeEmulatorCore = emulatorCore
                
                self.updateAutoSaveState()
            }
            else
            {
                gamesViewController.theme = .opaque
            }
            
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
            pauseViewController.closeButtonTitle = self.isGameScene ? NSLocalizedString("Close", comment: "") : NSLocalizedString("Main Menu", comment: "")
            
            pauseViewController.fastForwardItem?.isSelected = (self.emulatorCore?.rate != self.emulatorCore?.deltaCore.supportedRates.lowerBound)
            pauseViewController.fastForwardItem?.action = { [unowned self] item in
                self.performFastForwardAction(activate: item.isSelected)
            }
            pauseViewController.screenshotItem?.action = { [unowned self] item in
                self.performScreenshotAction()
            }
            
            pauseViewController.sustainButtonsItem?.isSelected = gameController.sustainedInputs.count > 0
            pauseViewController.sustainButtonsItem?.action = { [unowned self, unowned pauseViewController] item in
                
                for input in gameController.sustainedInputs.keys
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
            
            if self.emulatorCore?.deltaCore.supportedRates.upperBound == 1
            {
                pauseViewController.fastForwardItem = nil
            }
            
            switch self.game?.type
            {
            case .ds? where self.emulatorCore?.deltaCore == DS.core:
                // Cheats are not supported by DeSmuME core.
                pauseViewController.cheatCodesItem = nil
                
            case .genesis?:
                // GPGX core does not support cheats yet.
                pauseViewController.cheatCodesItem = nil

            default: break
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
                
                if self.emulatorCore?.deltaCore == MelonDS.core, ProcessInfo.processInfo.isJITAvailable
                {
                    self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                        self.showJITEnabledAlert()
                    })
                }
            }
            
            self.startGameActivity()
            
        case "unwindToGames":
            if self.isGameScene
            {
                guard let session = self.view.window?.windowScene?.session else { return }
                UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                    Logger.main.error("Failed to close game window. \(error.localizedDescription, privacy: .public)")
                }
                
                // Ensure emulation stops when explicitly quit.
                self.emulatorCore?.stop()
            }
            else
            {
                DispatchQueue.main.async {
                    self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                        self.performSegue(withIdentifier: "showGamesViewController", sender: nil)
                    })
                }
            }
                        
        default: break
        }
    }
    
    @IBAction private func unwindFromGamesViewController(with segue: UIStoryboardSegue)
    {
        self.pausedSaveState = nil
        
        if let emulatorCore = self.emulatorCore, emulatorCore.state == .paused
        {
            emulatorCore.resume()
        }
    }
    
    // MARK: - KVO
    /// KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }
        
        guard let rawValue = change?[.oldKey] as? Int, let previousState = EmulatorCore.State(rawValue: rawValue) else { return }
        
        if let saveState = _deepLinkResumingSaveState, let emulatorCore = self.emulatorCore, emulatorCore.state == .running
        {
            emulatorCore.pause()
            
            do
            {
                try emulatorCore.load(saveState)
            }
            catch
            {
                print(error)
            }
            
            _deepLinkResumingSaveState = nil
            emulatorCore.resume()
        }
        
        if previousState == .stopped
        {
            self.emulatorCore?.updateCheats()
        }
        
        if self.emulatorCore?.state == .running
        {
            DatabaseManager.shared.performBackgroundTask { (context) in
                guard let game = self.game as? Game else { return }
                
                let backgroundGame = context.object(with: game.objectID) as! Game
                backgroundGame.playedDate = Date()
                
                context.saveWithErrorLogging()
            }
        }
    }
}

//MARK: - Emulation -
private extension GameViewController
{
    func quitEmulation()
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.quitEmulation()
            }
            
            return
        }
        
        self.updateAutoSaveState()
        
        self.emulatorCore?.stop()
        self.game = nil
        
        // Make sure split view controller doesn't accidentally re-appear.
        self.controllerView.resignFirstResponder()
        
        if self.isGameScene
        {
            guard let session = self.view.window?.windowScene?.session else { return }
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                Logger.main.error("Failed to close game window. \(error.localizedDescription, privacy: .public)")
            }
        }
        else
        {
            self.performSegue(withIdentifier: "showGamesViewController", sender: nil)
        }
        
        self.stopGameActivity()
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
        if let index = Settings.localControllerPlayerIndex, !ExternalGameControllerManager.shared.connectedControllers.contains(where: { $0.playerIndex == index })
        {
            self.controllerView.playerIndex = index
            self.controllerView.isHidden = false
        }
        else
        {
            if let game = self.game,
               let traits = self.controllerView.controllerSkinTraits,
               let controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: game.type),
               controllerSkin.hasTouchScreen(for: traits)
            {
                self.controllerView.isHidden = false
                self.controllerView.playerIndex = 0
            }
            else
            {
                self.controllerView.isHidden = true
                self.controllerView.playerIndex = nil
            }

            Settings.localControllerPlayerIndex = nil
        }
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        
        // Roundabout way of combining arrays to prevent rare runtime crash in + operator :(
        var controllers = [GameController]()
        controllers.append(self.controllerView)
        controllers.append(contentsOf: ExternalGameControllerManager.shared.connectedControllers)
        
        if let emulatorCore = self.emulatorCore, let game = self.game
        {
            for gameController in controllers
            {
                if gameController.playerIndex != nil
                {
                    let inputMapping: GameControllerInputMappingProtocol
                    
                    if let mapping = GameControllerInputMapping.inputMapping(for: gameController, gameType: game.type, in: DatabaseManager.shared.viewContext)
                    {
                        inputMapping = mapping
                    }
                    else
                    {
                        inputMapping = DefaultInputMapping(gameController: gameController)
                    }
                    
                    gameController.addReceiver(self, inputMapping: inputMapping)
                    gameController.addReceiver(emulatorCore, inputMapping: inputMapping)
                }
                else
                {
                    gameController.removeReceiver(self)
                    gameController.removeReceiver(emulatorCore)
                }
            }
        }
        
        if self.shouldResetSustainedInputs
        {
            for controller in controllers
            {
                for input in controller.sustainedInputs.keys
                {
                    controller.unsustain(input)
                }
            }
            
            self.shouldResetSustainedInputs = false
        }
        
        self.controllerView.isButtonHapticFeedbackEnabled = Settings.isButtonHapticFeedbackEnabled
        self.controllerView.isThumbstickHapticFeedbackEnabled = Settings.isThumbstickHapticFeedbackEnabled
        
        self.updateControllerSkin()
    }
    
    func updateControllerSkin()
    {
        guard let game = self.game as? Game, let window = self.view.window else { return }
        
        let traits = DeltaCore.ControllerSkin.Traits.defaults(for: window)
        
        if Settings.localControllerPlayerIndex != nil
        {
            let controllerSkin = Settings.preferredControllerSkin(for: game, traits: traits)
            self.controllerView.controllerSkin = controllerSkin
        }
        else if let controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: game.type), controllerSkin.hasTouchScreen(for: traits)
        {
            var touchControllerSkin = TouchControllerSkin(controllerSkin: controllerSkin)
            
            if UIApplication.shared.isExternalDisplayConnected
            {
                // Only show touch screen if external display is connected.
                touchControllerSkin.screenPredicate = { $0.isTouchScreen }
            }
                        
            if self.view.bounds.width > self.view.bounds.height
            {
                touchControllerSkin.screenLayoutAxis = .horizontal
            }
            else
            {
                touchControllerSkin.screenLayoutAxis = .vertical
            }
            
            self.controllerView.controllerSkin = touchControllerSkin
        }
        
        self.updateExternalDisplay()
        
        self.view.setNeedsLayout()
    }
    
    func updateGameViews()
    {
        if self.isContinuingHandoff
        {
            // Continuing from Handoff which may take a while, so hide all views.
            for gameView in self.gameViews
            {
                gameView.isEnabled = false
                gameView.isHidden = true
            }
        }
        else if UIApplication.shared.isExternalDisplayConnected
        {
            // AirPlaying, hide all (non-touch) screens.
            
            if let traits = self.controllerView.controllerSkinTraits,
               let supportedTraits = self.controllerView.controllerSkin?.supportedTraits(for: traits),
               let screens = self.controllerView.controllerSkin?.screens(for: supportedTraits)
            {
                for (screen, gameView) in zip(screens, self.gameViews)
                {
                    gameView.isEnabled = screen.isTouchScreen
                    
                    if gameView == self.gameView && !(screen.isTouchScreen && Settings.features.dsAirPlay.topScreenOnly)
                    {
                        // Always show AirPlay indicator on self.gameView, unless it is a touch screen AND we're only AirPlaying top screen.
                        gameView.isAirPlaying = true
                        gameView.isHidden = false
                    }
                    else
                    {
                        gameView.isAirPlaying = false
                        gameView.isHidden = !screen.isTouchScreen
                    }
                }
            }
            else
            {
                // Either self.controllerView.controllerSkin is `nil`, or it doesn't support these traits.
                // Most likely this system only has 1 screen, so just hide self.gameView.
                
                self.gameView.isEnabled = false
                self.gameView.isHidden = false
                self.gameView.isAirPlaying = true
            }
        }
        else
        {
            // Not AirPlaying, show all screens.
            
            if let traits = self.controllerView.controllerSkinTraits,
               let supportedTraits = self.controllerView.controllerSkin?.supportedTraits(for: traits),
               let screens = self.controllerView.controllerSkin?.screens(for: supportedTraits),
               ExperimentalFeatures.shared.reverseScreens.isEnabled
            {
                for (screen, gameView) in zip(screens, self.gameViews)
                {
                    gameView.isAirPlaying = false
                    
                    if let outputFrame = screen.outputFrame, outputFrame.isEmpty
                    {
                        // Frame is empty, so always disable it,
                        gameView.isEnabled = false
                        gameView.isHidden = true
                    }
                    else
                    {
                        gameView.isEnabled = true
                        gameView.isHidden = false
                    }
                }
            }
            else
            {
                for gameView in self.gameViews
                {
                    gameView.isEnabled = true
                    gameView.isHidden = false
                    gameView.isAirPlaying = false
                }
            }
        }
    }
}

//MARK: - Game Saves -
/// Game Saves
private extension GameViewController
{
    func updateGameSave()
    {
        guard let game = self.game as? Game else { return }
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            do
            {
                let game = context.object(with: game.objectID) as! Game
                
                let hash = try RSTHasher.sha1HashOfFile(at: game.gameSaveURL)
                let previousHash = game.gameSave?.sha1
                
                guard hash != previousHash else { return }
                
                if let gameSave = game.gameSave
                {
                    gameSave.modifiedDate = Date()
                    gameSave.sha1 = hash
                }
                else
                {
                    let gameSave = GameSave(context: context)
                    gameSave.identifier = game.identifier
                    gameSave.sha1 = hash
                    
                    game.gameSave = gameSave
                }
                
                try context.save()
                
                if ExperimentalFeatures.shared.toastNotifications.gameSaveEnabled
                {
                    self.presentExperimentalToastView(NSLocalizedString("Game Data Saved", comment: ""))
                }
            }
            catch CocoaError.fileNoSuchFile
            {
                // Ignore
            }
            catch
            {
                print("Error updating game save.", error)
            }
        }
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
        
        guard let emulatorCore = self.emulatorCore, emulatorCore.state != .stopped else { return }
        
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
        
        if let snapshot = self.emulatorCore?.videoManager.snapshot(), let data = snapshot.pngData()
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
        saveState.coreIdentifier = self.emulatorCore?.deltaCore.identifier
        saveState.coreVersion = self.emulatorCore?.deltaCore.version
        
        if ExperimentalFeatures.shared.toastNotifications.stateSaveEnabled,
           saveState.type != .auto
        {
            self.presentExperimentalToastView(NSLocalizedString("Saved Save State", comment: ""))
        }
        
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
            
            if ExperimentalFeatures.shared.toastNotifications.stateLoadEnabled
            {
                self.presentExperimentalToastView(NSLocalizedString("Loaded Save State", comment: ""))
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

//MARK: - Audio -
/// Audio
private extension GameViewController
{
    func updateAudio()
    {
        self.emulatorCore?.audioManager.respectsSilentMode = Settings.respectSilentMode
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
        } completion: { _ in
            self.controllerView.becomeFirstResponder()
        }
    }
    
    func hideSustainButtonView()
    {
        guard let gameController = self.pausingGameController else { return }
        
        self.isSelectingSustainedButtons = false
        
        self.updateControllers()
        self.sustainInputsMapping = nil
        
        // Activate all sustained inputs, since they will now be mapped to game inputs.
        for (input, value) in self.inputsToSustain
        {
            gameController.sustain(input, value: value)
        }
        
        let blurEffect = self.sustainButtonsBlurView.effect
        
        UIView.animate(withDuration: 0.4, animations: {
            self.sustainButtonsBlurView.effect = nil
            self.sustainButtonsBackgroundView.alpha = 0.0
        }) { (finished) in
            self.sustainButtonsContentView.isHidden = true
            self.sustainButtonsBlurView.effect = blurEffect
        }
        
        self.inputsToSustain = [:]
    }
}

//MARK: - Action Inputs -
/// Action Inputs
extension GameViewController
{
    @objc func performQuickSaveAction()
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
    
    @objc func performQuickLoadAction()
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
            if ExperimentalFeatures.shared.variableFastForward.isEnabled,
               let preferredSpeed = ExperimentalFeatures.shared.variableFastForward[emulatorCore.game.type],
               (preferredSpeed.rawValue <= emulatorCore.deltaCore.supportedRates.upperBound || ExperimentalFeatures.shared.variableFastForward.allowUnrestrictedSpeeds)
            {
                emulatorCore.rate = preferredSpeed.rawValue
            }
            else
            {
                emulatorCore.rate = emulatorCore.deltaCore.supportedRates.upperBound
            }
            
            if ExperimentalFeatures.shared.toastNotifications.fastForwardEnabled
            {
                self.presentExperimentalToastView(NSLocalizedString("Fast Forward Enabled", comment: ""))
            }
        }
        else
        {
            emulatorCore.rate = emulatorCore.deltaCore.supportedRates.lowerBound
            
            if ExperimentalFeatures.shared.toastNotifications.fastForwardEnabled
            {
                self.presentExperimentalToastView(NSLocalizedString("Fast Forward Disabled", comment: ""))
            }
        }
    }
    
    func performScreenshotAction()
    {
        guard let snapshot = self.emulatorCore?.videoManager.snapshot() else { return }

        let imageScale = ExperimentalFeatures.shared.gameScreenshots.size?.rawValue ?? 1.0
        let imageSize = CGSize(width: snapshot.size.width * imageScale, height: snapshot.size.height * imageScale)
        
        let screenshotData: Data
        if imageScale == 1, let data = snapshot.pngData()
        {
            // No need to redraw image because it's already the correct size.
            screenshotData = data
        }
        else
        {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            
            let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
            screenshotData = renderer.pngData { (context) in
                context.cgContext.interpolationQuality = .none
                snapshot.draw(in: CGRect(origin: .zero, size: imageSize))
            }
        }
        
        if ExperimentalFeatures.shared.gameScreenshots.saveToPhotos
        {
            PHPhotoLibrary.runIfAuthorized
            {
                PHPhotoLibrary.saveImageData(screenshotData)
            }
        }
        
        if ExperimentalFeatures.shared.gameScreenshots.saveToFiles
        {
            let screenshotsDirectory = FileManager.default.documentsDirectory.appendingPathComponent("Screenshots")
            
            do
            {
                try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            catch
            {
                print(error)
            }
            
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            
            let fileName: URL
            if let game = self.game as? Game
            {
                let filename = game.name + "_" + dateFormatter.string(from: date) + ".png"
                fileName = screenshotsDirectory.appendingPathComponent(filename)
            }
            else
            {
                fileName = screenshotsDirectory.appendingPathComponent(dateFormatter.string(from: date) + ".png")
            }
            
            do
            {
                try screenshotData.write(to: fileName)
            }
            catch
            {
                print(error)
            }
        }
        
        self.pauseViewController?.screenshotItem?.isSelected = false
    }
    
    func performReverseScreensAction()
    {
        guard let controllerSkin = self.controllerView.controllerSkin as? ControllerSkin else { return }
        controllerSkin.isReversingScreens.toggle()
        
        self.updateControllerSkin()
    }
}

private extension GameViewController
{
    func connectExternalDisplay(for scene: ExternalDisplayScene)
    {
        // hasKeyboardFocus is false when enabling AirPlay via Control Center, so can't rely on that.
        // guard let windowScene = self.view.window?.windowScene, windowScene.hasKeyboardFocus else { return }
        
        // We need to receive gameViewController(_:didUpdateGameViews:) callback.
        scene.gameViewController.delegate = self
                
        self.updateControllerSkin()
        
        // Implicitly called from updateControllerSkin()
        // self.updateExternalDisplay()
        
        self.updateGameViews()
    }
    
    func updateExternalDisplay()
    {
        guard let scene = UIApplication.shared.externalDisplayScene, scene.gameViewController.delegate === self else { return }
        
        if scene.game?.fileURL != self.game?.fileURL
        {
            scene.game = self.game
        }
        
        var controllerSkin: ControllerSkinProtocol?
        
        if let game = self.game, let system = System(gameType: game.type), let traits = scene.gameViewController.controllerView.controllerSkinTraits
        {
            //TODO: Support per-game AirPlay skins
            if let preferredControllerSkin = Settings.preferredControllerSkin(for: system, traits: traits), preferredControllerSkin.supports(traits)
            {
                // Use preferredControllerSkin directly.
                controllerSkin = preferredControllerSkin
            }
            else if let standardSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: game.type), standardSkin.supports(traits)
            {
                if standardSkin.hasTouchScreen(for: traits)
                {
                    // Only use TouchControllerSkin for standard controller skins with touch screens.
                    
                    var touchControllerSkin = DeltaCore.TouchControllerSkin(controllerSkin: standardSkin)
                    touchControllerSkin.screenLayoutAxis = Settings.features.dsAirPlay.layoutAxis

                    if Settings.features.dsAirPlay.topScreenOnly
                    {
                        touchControllerSkin.screenPredicate = { !$0.isTouchScreen }
                    }

                    controllerSkin = touchControllerSkin
                }
                else
                {
                    controllerSkin = standardSkin
                }
            }
        }
        
        scene.gameViewController.controllerView.controllerSkin = controllerSkin
        
        // Implicitly called when assigning controllerSkin.
        // self.updateExternalDisplayGameViews()
    }
    
    func updateExternalDisplayGameViews()
    {
        guard let scene = UIApplication.shared.externalDisplayScene, let emulatorCore = self.emulatorCore, scene.gameViewController.delegate === self else { return }
        
        for gameView in scene.gameViewController.gameViews
        {
            emulatorCore.add(gameView)
            gameView.exclusiveVideoManager = emulatorCore.videoManager
            
            // GameView must layout subviews after resetting EAGLContext before it can render frames.
            // Fixes external display screen sometimes not updating when switching back to paused game.
            gameView.setNeedsLayout()
            gameView.layoutIfNeeded()
        }
    }
    
    func disconnectExternalDisplay(for scene: ExternalDisplayScene)
    {
        if scene.gameViewController.delegate === self
        {
            scene.gameViewController.delegate = nil
        }
        
        for gameView in scene.gameViewController.gameViews
        {
            self.emulatorCore?.remove(gameView)
        }
        
        self.updateControllerSkin() // Reset TouchControllerSkin + GameViews
        self.updateGameViews() // Ensure we re-enable GameView and hide AirPlay message.
    }
}

//MARK: - GameViewControllerDelegate -
/// GameViewControllerDelegate
extension GameViewController: GameViewControllerDelegate
{
    func gameViewController(_ gameViewController: DeltaCore.GameViewController, handleMenuInputFrom gameController: GameController)
    {
        guard gameViewController == self else { return }
        
        guard !self.ignoreNextMenuInput else {
            self.ignoreNextMenuInput = false
            return
        }
        
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
            self.controllerView.resignFirstResponder()
            
            self.performSegue(withIdentifier: "pause", sender: gameController)
        }
    }
    
    func gameViewControllerShouldResumeEmulation(_ gameViewController: DeltaCore.GameViewController) -> Bool
    {
        guard gameViewController == self else { return false }
        guard !self.isContinuingHandoff else { return false }
        
        var result = false
        
        rst_dispatch_sync_on_main_thread {
            result = (self.presentedViewController == nil || self.presentedViewController?.isDisappearing == true) && !self.isSelectingSustainedButtons && self.view.window != nil
        }
        
        return result
    }
    
    func gameViewController(_ gameViewController: DeltaCore.GameViewController, didUpdateGameViews gameViews: [GameView])
    {
        // gameViewController could be `self` or ExternalDisplayScene.gameViewController.
        
        if gameViewController == self
        {
            self.updateGameViews()
        }
        else
        {
            self.updateExternalDisplayGameViews()
        }
    }
}

//MARK: - Gestures -
/// Gestures
extension GameViewController
{
    private func makeMenuButtonGestureRecognizers() -> Set<UIGestureRecognizer>
    {
        var gestureRecognizers = Set<UIGestureRecognizer>()
        
        let fastForwardSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(GameViewController.handleSwipeGesture(_:)))
        fastForwardSwipeGestureRecognizer.delegate = self
        fastForwardSwipeGestureRecognizer.direction = [.left, .right]
        gestureRecognizers.insert(fastForwardSwipeGestureRecognizer)
        
        let quickLoadGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(GameViewController.handleQuickLoadGesture(_:)))
        quickLoadGestureRecognizer.delegate = self
        quickLoadGestureRecognizer.numberOfTapsRequired = 0
        gestureRecognizers.insert(quickLoadGestureRecognizer)
        
        let quickSaveGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(GameViewController.handleQuickSaveGesture(_:)))
        quickSaveGestureRecognizer.delegate = self
        quickSaveGestureRecognizer.numberOfTapsRequired = 2
        quickSaveGestureRecognizer.require(toFail: quickLoadGestureRecognizer)
        gestureRecognizers.insert(quickSaveGestureRecognizer)
        
        return gestureRecognizers
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    {
        guard super.gestureRecognizer(gestureRecognizer, shouldReceive: touch) else { return false }
        
        if self.menuButtonGestureRecognizers.contains(gestureRecognizer) || self.menuButtonKeyboardGestureRecognizers.contains(gestureRecognizer)
        {
            let shouldBegin = self.isMenuButtonHeldDown && Settings.isQuickGesturesEnabled
            return shouldBegin
        }
        
        // Default to true, as if this method wasn't overridden.
        return true
    }
    
    @objc private func handleSwipeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        guard let emulatorCore = self.emulatorCore else { return }
        
        let isFastForwarding = (emulatorCore.rate != emulatorCore.deltaCore.supportedRates.lowerBound)
        self.performFastForwardAction(activate: !isFastForwarding)
        
        self.ignoreNextMenuInput = true
    }
    
    @objc private func handleQuickSaveGesture(_ gestureRecognizer: UITapGestureRecognizer)
    {
        self.performQuickSaveAction()
        self.ignoreNextMenuInput = true
    }
    
    @objc private func handleQuickLoadGesture(_ gestureRecognizer: UILongPressGestureRecognizer)
    {
        self.performQuickLoadAction()
        self.ignoreNextMenuInput = true
        
        // Cancel gesture to prevent additional callbacks
        gestureRecognizer.isEnabled = false
        gestureRecognizer.isEnabled = true
    }
}

private extension GameViewController
{
    func show(_ toastView: RSTToastView, duration: TimeInterval = 3.0)
    {
        toastView.textLabel.textAlignment = .center
        toastView.presentationEdge = .top
        toastView.show(in: self.view, duration: duration)
    }
    
    func showJITEnabledAlert()
    {
        guard !self.presentedJITAlert, self.presentedViewController == nil, self.game != nil else { return }
        self.presentedJITAlert = true
        
        func presentToastView()
        {
            let detailText: String?
            let duration: TimeInterval
            
            if UserDefaults.standard.jitEnabledAlertCount < 3
            {
                detailText = NSLocalizedString("You can now Fast Forward DS games up to 3x speed.", comment: "")
                duration = 5.0
            }
            else
            {
                detailText = nil
                duration = 2.0
            }
            
            let toastView = RSTToastView(text: NSLocalizedString("JIT Compilation Enabled", comment: ""), detailText: detailText)
            toastView.edgeOffset.vertical = 8
            self.show(toastView, duration: duration)
            
            UserDefaults.standard.jitEnabledAlertCount += 1
        }
        
        DispatchQueue.main.async {
            if let transitionCoordinator = self.transitionCoordinator
            {
                transitionCoordinator.animate(alongsideTransition: nil) { (context) in
                    presentToastView()
                }
            }
            else
            {
                presentToastView()
            }
        }
    }
}

//MARK: - Handoff -
extension GameViewController: NSUserActivityDelegate
{
    func prepareForHandoff()
    {
        guard !self.isContinuingHandoff else { return }
        self.isContinuingHandoff = true
        
        self.updateGameViews()
        
        self.handoffPlaceholderView.alpha = 1.0
        self.handoffPlaceholderView.isHidden = false
    }
    
    func finishHandoff()
    {
        guard self.isContinuingHandoff else { return }
        self.isContinuingHandoff = false
        
        self.updateGameViews()
        
        UIView.animate(withDuration: 0.4) {
            self.handoffPlaceholderView.alpha = 0.0
        } completion: { _ in
            self.handoffPlaceholderView.isHidden = true
        }
    }
    
    func startGameActivity()
    {
        if let userActivity = self.view.window?.windowScene?.userActivity, userActivity.activityType == NSUserActivity.playGameActivityType,
           let gameID = userActivity.userInfo?[NSUserActivity.gameIDKey] as? String, let game = self.game as? Game, game.identifier == gameID
        {
            // There is an existing activity for this game, so make it the current activity.
            userActivity.becomeCurrent()
        }
        else if let game = self.game as? Game
        {
            // No existing activity, or activity is different type, so create new activity.
            
            let userActivity = NSUserActivity(game: game)
            userActivity.delegate = self
            userActivity.isEligibleForHandoff = true
            userActivity.supportsContinuationStreams = true
            userActivity.userInfo?[NSUserActivity.isSaveStateAvailable] = true // Allow transferring save states via Handoff
            userActivity.requiredUserInfoKeys?.insert(NSUserActivity.isSaveStateAvailable)
            userActivity.becomeCurrent()
            self.view.window?.windowScene?.userActivity = userActivity
        }
        else
        {
            // No game, so stop current activity instead.
            self.stopGameActivity()
        }
    }
    
    func pauseGameActivity()
    {
        guard let userActivity = self.view.window?.windowScene?.userActivity, userActivity.activityType == NSUserActivity.playGameActivityType else { return }
        userActivity.resignCurrent()
    }
    
    func stopGameActivity()
    {
        self.pauseGameActivity()
        self.view.window?.windowScene?.userActivity = nil
    }
    
    func userActivity(_ userActivity: NSUserActivity, didReceive inputStream: InputStream, outputStream: OutputStream)
    {
        inputStream.open()
        outputStream.open()
        
        let isRunning = (self.emulatorCore?.state == .running)
        if isRunning
        {
            self.pauseEmulation()
        }
        
        let temporaryURL = FileManager.default.uniqueTemporaryURL()
        self.emulatorCore?.saveSaveState(to: temporaryURL)
        
        Task<Void, Never> {
            do
            {
                if #available(iOS 16, *)
                {
                    // Wait for save state to flush to disk (necessary for N64).
                    try await Task.sleep(for: .seconds(0.5))
                }

                defer {
                    try? FileManager.default.removeItem(at: temporaryURL)
                }
                
                let data = try Data(contentsOf: temporaryURL)
                try await outputStream.send(data)
                
                self.quitEmulation()
            }
            catch
            {
                Logger.main.error("Failed to send save state for Handoff. \(error.localizedDescription, privacy: .public)")
                
                if isRunning
                {
                    self.resumeEmulation()
                }
            }
            
            inputStream.close()
            outputStream.close()
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
        case .localControllerPlayerIndex, .isButtonHapticFeedbackEnabled, .isThumbstickHapticFeedbackEnabled:
            self.updateControllers()

        case .preferredControllerSkin:
            guard
                let system = notification.userInfo?[Settings.NotificationUserInfoKey.system] as? System,
                let traits = notification.userInfo?[Settings.NotificationUserInfoKey.traits] as? DeltaCore.ControllerSkin.Traits
            else { return }
                        
            if system.gameType == self.game?.type && traits.orientation == self.controllerView.controllerSkinTraits?.orientation
            {
                self.updateControllerSkin()
            }
            
        case .translucentControllerSkinOpacity:
            self.controllerView.translucentControllerSkinOpacity = Settings.translucentControllerSkinOpacity
            
        case .respectSilentMode:
            self.updateAudio()
                
        case .syncingService, .isAltJITEnabled: break
            
        case Settings.features.dsAirPlay.$topScreenOnly.settingsKey: fallthrough
        case Settings.features.dsAirPlay.$layoutAxis.settingsKey:
            self.updateExternalDisplay()
        
        case ExperimentalFeatures.shared.airPlaySkins.settingsKey: fallthrough
        case _ where settingsName.rawValue.hasPrefix(ExperimentalFeatures.shared.airPlaySkins.settingsKey.rawValue):
            // Update whenever any of the AirPlay skins have changed.
            self.updateExternalDisplay()
            
        case .pauseWhileInactive: self.automaticallyPausesWhileInactive = Settings.pauseWhileInactive
        case .supportsExternalDisplays:
            // May return nil if Settings.supportsExternalDisplays is false
            // guard let externalDisplayScene = UIApplication.shared.externalDisplayScene else { break }
            
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? ExternalDisplayScene }).first(where: { $0.session.role == .windowExternalDisplay }) else { break }
            
            if Settings.supportsExternalDisplays /*, scene.hasKeyboardFocus */ // Connect all scenes, not just one with keyboard focus.
            {
                self.connectExternalDisplay(for: scene)
            }
            else
            {
                self.disconnectExternalDisplay(for: scene)
            }
            
            
        default: break
        }
    }
    
    @objc func deepLinkControllerWillLaunchGame(with notification: Notification)
    {
        guard let game = notification.userInfo?[DeepLink.Key.game] as? Game, let scene = notification.userInfo?[DeepLink.Key.scene] as? UIScene, scene == self.view.window?.windowScene else { return }
        
        // Game won't start until we call finishHandoff()
        self.game = game
        self.prepareForHandoff()
        
        self.returnToGameViewController()
    }
    
    @objc func deepLinkControllerLaunchGame(with notification: Notification)
    {
        guard let game = notification.userInfo?[DeepLink.Key.game] as? Game, let scene = notification.userInfo?[DeepLink.Key.scene] as? UIScene, scene == self.view.window?.windowScene else { return }
        
        let previousGame = self.game
        self.game = game
        
        if self.isContinuingHandoff
        {
            let error = notification.userInfo?[DeepLink.Key.error] as? Error
            self.finishHandoff()
            
            if let saveState = notification.userInfo?[DeepLink.Key.saveState] as? SaveStateProtocol
            {
                // Included save state with deep link, so load it when emulator core is started.
                // Note: Will be automatically deleted when loaded, so make a copy if it's important.
                _deepLinkResumingSaveState = saveState
            }
            
            if let error
            {
                let toastView = RSTToastView(text: NSLocalizedString("Handoff Failed", comment: ""), detailText: error.localizedDescription)
                self.show(toastView)
            }
        }
        else if let pausedSaveState = self.pausedSaveState, game == (previousGame as? Game)
        {
            // Launching current game via deep link, so we store a copy of the paused save state to resume when emulator core is started.
            
            do
            {
                let temporaryURL = FileManager.default.uniqueTemporaryURL()
                try FileManager.default.copyItem(at: pausedSaveState.fileURL, to: temporaryURL)
                
                _deepLinkResumingSaveState = DeltaCore.SaveState(fileURL: temporaryURL, gameType: game.type)
            }
            catch
            {
                Logger.main.error("Failed to resume save state after deep link. \(error.localizedDescription, privacy: .public)")
            }
        }
                
        self.returnToGameViewController() {
            self.resumeEmulation()
        }
    }
    
    func returnToGameViewController(completion: (() -> Void)? = nil)
    {
        if let pauseViewController = self.pauseViewController
        {
            let segue = UIStoryboardSegue(identifier: "unwindFromPauseMenu", source: pauseViewController, destination: self)
            self.unwindFromPauseViewController(segue)
        }
        else if
            let navigationController = self.presentedViewController as? UINavigationController,
            let pageViewController = navigationController.topViewController?.children.first as? UIPageViewController,
            let gameCollectionViewController = pageViewController.viewControllers?.first as? GameCollectionViewController
        {
            let segue = UIStoryboardSegue(identifier: "unwindFromGames", source: gameCollectionViewController, destination: self)
            self.unwindFromGamesViewController(with: segue)
        }
        
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true, completion: completion)
        }
        else
        {
            completion?()
        }
    }
    
    @objc func didActivateGyro(with notification: Notification)
    {
        self.isGyroActive = true
        
        if #available(iOS 16, *)
        {
            DispatchQueue.main.async {
                self.setNeedsUpdateOfSupportedInterfaceOrientations()
                self.parent?.setNeedsUpdateOfSupportedInterfaceOrientations() // LaunchViewController
            }
        }
        
        guard !self.presentedGyroAlert else { return }
        
        self.presentedGyroAlert = true
        
        func presentToastView()
        {
            let toastView = RSTToastView(text: NSLocalizedString("Autorotation Disabled", comment: ""), detailText: NSLocalizedString("Pause game to change orientation.", comment: ""))
            self.show(toastView)
        }
        
        DispatchQueue.main.async {
            if let transitionCoordinator = self.transitionCoordinator
            {
                transitionCoordinator.animate(alongsideTransition: nil) { (context) in
                    presentToastView()
                }
            }
            else
            {
                presentToastView()
            }
        }
    }
    
    @objc func didDeactivateGyro(with notification: Notification)
    {
        self.isGyroActive = false
        
        if #available(iOS 16, *)
        {
            DispatchQueue.main.async {
                self.setNeedsUpdateOfSupportedInterfaceOrientations()
                self.parent?.setNeedsUpdateOfSupportedInterfaceOrientations() // LaunchViewController
            }
        }
    }
    
    @objc func didEnableJIT(with notification: Notification)
    {
        DispatchQueue.main.async {
            self.showJITEnabledAlert()
        }
        
        DispatchQueue.global(qos: .utility).async {
            guard let emulatorCore = self.emulatorCore, let emulatorBridge = emulatorCore.deltaCore.emulatorBridge as? MelonDSEmulatorBridge, !emulatorBridge.isJITEnabled
            else { return }
            
            guard emulatorCore.state != .stopped else {
                // Emulator core is not running, which means we can set
                // isJITEnabled to true without resetting the core.
                emulatorBridge.isJITEnabled = true
                return
            }
            
            let isVideoEnabled = emulatorCore.videoManager.isEnabled
            emulatorCore.videoManager.isEnabled = false
            
            let isRunning = (emulatorCore.state == .running)
            if isRunning
            {
                self.pauseEmulation()
            }
            
            let temporaryFileURL = FileManager.default.uniqueTemporaryURL()
            
            let saveState = emulatorCore.saveSaveState(to: temporaryFileURL)
            emulatorCore.stop()
            
            emulatorBridge.isJITEnabled = true
            
            emulatorCore.start()
            emulatorCore.pause()
            
            do
            {
                try emulatorCore.load(saveState)
            }
            catch
            {
                print("Failed to load save state after enabling JIT.", error)
            }
            
            if isRunning
            {
                self.resumeEmulation()
            }
            
            emulatorCore.videoManager.isEnabled = isVideoEnabled
        }
    }
    
    @objc func emulationDidQuit(with notification: Notification)
    {
        DispatchQueue.main.async {
            guard self.presentedViewController == nil else { return }
            
            // Wait for emulation to stop completely before performing segue.
            var token: NSKeyValueObservation?
            token = self.emulatorCore?.observe(\.state, options: [.initial]) { (emulatorCore, change) in
                guard emulatorCore.state == .stopped else { return }
                
                DispatchQueue.main.async {
                    self.quitEmulation()
                }
                
                token?.invalidate()
            }
        }
    }
    
    @objc func sceneWillConnect(with notification: Notification)
    {
        guard let scene = notification.object as? ExternalDisplayScene, Settings.supportsExternalDisplays else { return }
        self.connectExternalDisplay(for: scene)
    }
    
    @objc func sceneDidDisconnect(with notification: Notification)
    {
        // Always allow disconnecting external displays.
        // guard Settings.supportsExternalDisplays else { return }
        
        guard let scene = notification.object as? ExternalDisplayScene else { return }
        self.disconnectExternalDisplay(for: scene)
    }
    
    @objc func sceneSessionWillQuit(with notification: Notification)
    {
        guard let session = notification.object as? UISceneSession, let windowScene = self.view.window?.windowScene, session.scene == windowScene else { return }
        Logger.main.info("Discarding current scene session, quitting emulation for game \((self.game as? Game)?.identifier ?? "nil", privacy: .public)")
        
        self.updateAutoSaveState()
        self.emulatorCore?.stop() // Required to ensure data isn't corrupted due to starting new game before previous EmulatorBridge state is reset.
    }
    
    @objc func sceneKeyboardFocusDidChange(with notification: Notification)
    {
        guard let scene = notification.object as? UIWindowScene, scene == self.view.window?.windowScene else { return }
        guard let externalDisplayScene = UIApplication.shared.externalDisplayScene else { return }
        
        if scene.hasKeyboardFocus
        {
            self.connectExternalDisplay(for: externalDisplayScene)
            
            if self.presentedViewController == nil
            {
                self.startGameActivity()
            }
        }
        else
        {
            // DON'T disconnect, only connect when active (so it stays connected to last active scene)
        }
    }
    
    @objc func keyboardDidShow(with notification: Notification)
    {
        guard let inputView = self.controllerView.inputView else { return }
        
        // Using keyboard game controller, so add gesture recognizers to keyboard.
        for gestureRecognizer in self.menuButtonKeyboardGestureRecognizers
        {
            inputView.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    @objc func keyboardDidChangeFrame(with notification: Notification)
    {
        self.keyboardDidShow(with: notification)
    }
}

private extension UserDefaults
{
    @NSManaged var desmumeDeprecatedAlertCount: Int
    
    @NSManaged var jitEnabledAlertCount: Int
}
