//
//  EmulationViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import Roxas

class EmulationViewController: UIViewController
{
    //MARK: - Properties -
    /** Properties **/
    
    /// Should only be set when preparing for segue. Otherwise, should be considered immutable
    var game: Game! {
        didSet
        {
            guard oldValue != game else { return }

            self.emulatorCore = EmulatorCore(game: game)
            
        }
    }
    private(set) var emulatorCore: EmulatorCore! {
        didSet
        {
            self.preferredContentSize = self.emulatorCore.preferredRenderingSize
        }
    }
    
    // If non-nil, will override the default preview action items returned in previewActionItems()
    var overridePreviewActionItems: [UIPreviewActionItem]?
    
    // Annoying iOS gotcha: if the previewingContext(_:viewControllerForLocation:) callback takes too long, the peek/preview starts, but fails to actually present the view controller
    // To workaround, we have this closure to defer work for Peeking/Popping until the view controller appears
    // Hacky, but works
    var deferredPreparationHandler: (Void -> Void)?
    
    //MARK: - Private Properties
    @IBOutlet private var controllerView: ControllerView!
    @IBOutlet private var gameView: GameView!
    @IBOutlet private var sustainButtonContentView: UIView!
    @IBOutlet private var backgroundView: RSTBackgroundView!
    
    @IBOutlet private var controllerViewHeightConstraint: NSLayoutConstraint!
    
    private var pauseViewController: PauseViewController?
    
    private var context = CIContext(options: [kCIContextWorkingColorSpace: NSNull()])


    private var selectingSustainedButton = false {
        didSet {
            self.sustainButtonContentView.alpha = self.selectingSustainedButton ? 1.0 : 0.0
        }
    }
    
    
    //MARK: - Initializers -
    /** Initializers **/
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
                
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EmulationViewController.updateControllers), name: ExternalControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EmulationViewController.updateControllers), name: ExternalControllerDidDisconnectNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EmulationViewController.willResignActive(_:)), name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
         NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EmulationViewController.didBecomeActive(_:)), name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
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
        
        self.backgroundView.textLabel.text = NSLocalizedString("Select Button to Sustain", comment: "")
        self.backgroundView.detailTextLabel.text = NSLocalizedString("Sustained buttons act as though they're being held down, without needing to do so yourself. This is particularly useful for certain games, such as platformers which require you to hold down a button to run.", comment: "")
        
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
        
        self.deferredPreparationHandler?()
        self.deferredPreparationHandler = nil
        
        // Yes, order DOES matter here, in order to prevent audio from being slightly delayed after peeking with 3D Touch (ugh so tired of that issue)
        switch self.emulatorCore.state
        {
        case .Stopped:
            self.emulatorCore.startEmulation()
            self.updateCheats()
            
        case .Running: break
        case .Paused:
            self.updateCheats()
            self.resumeEmulation()
        }
        
        // Toggle audioManager.enabled to reset the audio buffer and ensure the audio isn't delayed from the beginning
        // This is especially noticeable when peeking a game
        self.emulatorCore.audioManager.enabled = false
        self.emulatorCore.audioManager.enabled = true
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
        
        self.controllerView.hidden = self.isPreviewing
    }
    
    override func prefersStatusBarHidden() -> Bool
    {
        return true
    }
    
    /// <UIContentContainer>
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        self.controllerView.beginAnimatingUpdateControllerSkin()
        
        coordinator.animateAlongsideTransition({ _ in
            
            if self.pauseViewController != nil
            {
                // We need to manually "refresh" the game screen, otherwise the system tries to cache the rendered image, but skews it incorrectly when rotating b/c of UIVisualEffectView
                self.gameView.inputImage = self.gameView.outputImage
            }
            
        }, completion: { _ in
                self.controllerView.finishAnimatingUpdateControllerSkin()
        })
    }
    
    // MARK: - Navigation -
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        self.pauseEmulation()
        
        if segue.identifier == "pauseSegue"
        {
            let pauseViewController = segue.destinationViewController as! PauseViewController
            pauseViewController.pauseText = self.game.name
            
            // Swift has a bug where using unowned references can lead to swift_abortRetainUnowned errors.
            // Specifically, if you pause a game, open the save states menu, go back, return to menu, select a new game, then try to pause it, it will crash
            // As a dirty workaround, we just use a weak reference, and force unwrap it if needed
            
            let saveStateItem = PauseItem(image: UIImage(named: "SaveSaveState")!, text: NSLocalizedString("Save State", comment: ""), action: { [unowned self] _ in
                pauseViewController.presentSaveStateViewControllerWithMode(.Saving, delegate: self)
            })
            
            let loadStateItem = PauseItem(image: UIImage(named: "LoadSaveState")!, text: NSLocalizedString("Load State", comment: ""), action: { [unowned self] _ in
                pauseViewController.presentSaveStateViewControllerWithMode(.Loading, delegate: self)
            })
            
            let cheatCodesItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Cheat Codes", comment: ""), action: { [unowned self] _ in
                pauseViewController.presentCheatsViewController(delegate: self)
            })
            
            let sustainButtonItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Sustain Button", comment: ""), action: { [unowned self] item in
                
                if item.selected
                {
                    self.selectingSustainedButton = true
                    pauseViewController.dismiss()
                }
                
            })
            
            var fastForwardItem = PauseItem(image: UIImage(named: "FastForward")!, text: NSLocalizedString("Fast Forward", comment: ""), action: { [unowned self] item in
                self.emulatorCore.fastForwarding = item.selected
            })
            fastForwardItem.selected = self.emulatorCore.fastForwarding
            
            pauseViewController.items = [saveStateItem, loadStateItem, cheatCodesItem, fastForwardItem, sustainButtonItem]
            
            self.pauseViewController = pauseViewController
        }
    }
    
    @IBAction func unwindFromPauseViewController(segue: UIStoryboardSegue)
    {
        self.pauseViewController = nil
        
        if self.resumeEmulation()
        {
            // Temporarily disable audioManager to prevent delayed audio bug when using 3D Touch Peek & Pop
            self.emulatorCore.audioManager.enabled = false
            
            // Re-enable after delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                self.emulatorCore.audioManager.enabled = true
            }
        }
    }
    
    //MARK: - 3D Touch -
    /// 3D Touch
    override func previewActionItems() -> [UIPreviewActionItem]
    {
        if let previewActionItems = self.overridePreviewActionItems
        {
            return previewActionItems
        }
        
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

//MARK: - Emulation -
/// Emulation
private extension EmulationViewController
{
    func pauseEmulation() -> Bool
    {
        return self.emulatorCore.pauseEmulation()
    }
    
    func resumeEmulation() -> Bool
    {
        guard !self.selectingSustainedButton && self.pauseViewController == nil else { return false }
        
        return self.emulatorCore.resumeEmulation()
    }
}

//MARK: - Controllers/Inputs -
/// Controllers/Inputs
private extension EmulationViewController
{
    @objc func updateControllers()
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
    
    func setSelectingSustainedButton(selectingSustainedButton: Bool, animated: Bool)
    {
        if !animated
        {
            self.selectingSustainedButton = selectingSustainedButton
        }
        else
        {
            UIView.animateWithDuration(0.4) {
                self.selectingSustainedButton = selectingSustainedButton
            }
        }
    }
    
    func sustainInput(input: InputType, gameController: GameControllerType)
    {
        if let input = input as? ControllerInput
        {
            guard input != ControllerInput.Menu else
            {
                self.setSelectingSustainedButton(false, animated: true)
                self.performSegueWithIdentifier("pauseSegue", sender: gameController)
                return
            }
        }
        
        self.setSelectingSustainedButton(false, animated: true)
        
        self.resumeEmulation()
        
    }
}

//MARK: - Save States
/// Save States
extension EmulationViewController: SaveStatesViewControllerDelegate
{
    func saveStatesViewControllerActiveEmulatorCore(saveStatesViewController: SaveStatesViewController) -> EmulatorCore
    {
        return self.emulatorCore
    }
    
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    {
        guard let filepath = saveState.fileURL.path else { return }
        
        var updatingExistingSaveState = true
        
        self.emulatorCore.saveSaveState { temporarySaveState in
            do
            {
                if NSFileManager.defaultManager().fileExistsAtPath(filepath)
                {
                    try NSFileManager.defaultManager().replaceItemAtURL(saveState.fileURL, withItemAtURL: temporarySaveState.fileURL, backupItemName: nil, options: [], resultingItemURL: nil)
                }
                else
                {
                    try NSFileManager.defaultManager().moveItemAtURL(temporarySaveState.fileURL, toURL: saveState.fileURL)
                    
                    updatingExistingSaveState = false
                }
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        if let outputImage = self.gameView.outputImage
        {
            let quartzImage = self.context.createCGImage(outputImage, fromRect: outputImage.extent)
            
            let image = UIImage(CGImage: quartzImage)
            UIImagePNGRepresentation(image)?.writeToURL(saveState.imageFileURL, atomically: true)
        }
        
        saveState.modifiedDate = NSDate()
        
        // Dismiss if updating an existing save state.
        // If creating a new one, don't dismiss.
        if updatingExistingSaveState
        {
            self.pauseViewController?.dismiss()
        }
    }
    
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateType)
    {
        self.emulatorCore.loadSaveState(saveState)
        
        self.updateCheats()
        
        self.pauseViewController?.dismiss()
    }
}

//MARK: - Cheats
/// Cheats
extension EmulationViewController: CheatsViewControllerDelegate
{
    func cheatsViewControllerActiveEmulatorCore(saveStatesViewController: CheatsViewController) -> EmulatorCore
    {
        return self.emulatorCore
    }
    
    func cheatsViewController(cheatsViewController: CheatsViewController, didActivateCheat cheat: Cheat) throws
    {
        try self.emulatorCore.activateCheat(cheat)
    }
    
    func cheatsViewController(cheatsViewController: CheatsViewController, didDeactivateCheat cheat: Cheat)
    {
        self.emulatorCore.deactivateCheat(cheat)
    }
    
    private func updateCheats()
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlockAndWait {
            
            let running = (self.emulatorCore.state == .Running)
            
            if running
            {
                // Core MUST be paused when activating cheats, or else race conditions could crash the core
                self.pauseEmulation()
            }
            
            let predicate = NSPredicate(format: "%K == %@", Cheat.Attributes.game.rawValue, self.emulatorCore.game as! Game)
            
            let cheats = Cheat.instancesWithPredicate(predicate, inManagedObjectContext: backgroundContext, type: Cheat.self)
            for cheat in cheats
            {
                if cheat.enabled
                {
                    do
                    {
                        try self.emulatorCore.activateCheat(cheat)
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
                else
                {
                    self.emulatorCore.deactivateCheat(cheat)
                }
            }
            
            if running
            {
                self.resumeEmulation()
            }
            
        }
        
    }
}

//MARK: - App Lifecycle -
private extension EmulationViewController
{
    @objc func willResignActive(notification: NSNotification)
    {
        self.pauseEmulation()
    }
    
    @objc func didBecomeActive(notification: NSNotification)
    {
        self.resumeEmulation()
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
        
        guard !self.selectingSustainedButton else
        {
            self.sustainInput(input, gameController: gameController)
            return
        }
        
        guard let input = input as? ControllerInput else { return }
        
        print("Activated \(input)")
        
        switch input
        {
        case ControllerInput.Menu: self.performSegueWithIdentifier("pauseSegue", sender: gameController)
        }
    }
    
    func gameController(gameController: GameControllerType, didDeactivateInput input: InputType)
    {
        guard let input = input as? ControllerInput else { return }
        
        print("Deactivated \(input)")
    }
}
