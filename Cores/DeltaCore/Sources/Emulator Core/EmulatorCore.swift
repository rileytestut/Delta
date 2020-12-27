//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import AVFoundation

extension EmulatorCore
{
    @objc public static let emulationDidQuitNotification = Notification.Name("com.rileytestut.DeltaCore.emulationDidQuit")
    
    private static let didUpdateFrameNotification = Notification.Name("com.rileytestut.DeltaCore.didUpdateFrame")
}

public extension EmulatorCore
{
    @objc enum State: Int
    {
        case stopped
        case running
        case paused
    }
    
    enum CheatError: Error
    {
        case invalid
    }
    
    enum SaveStateError: Error
    {
        case doesNotExist
    }
}

@objc(DLTAEmulatorCore)
public final class EmulatorCore: NSObject
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameProtocol
    public private(set) var gameViews: [GameView] = []
    
    public var updateHandler: ((EmulatorCore) -> Void)?
    public var saveHandler: ((EmulatorCore) -> Void)?
    
    public let audioManager: AudioManager
    public let videoManager: VideoManager
    
    // KVO-Compliant
    @objc public private(set) dynamic var state = State.stopped
    @objc public dynamic var rate = 1.0 {
        didSet {
            self.audioManager.rate = self.rate
        }
    }
    
    public let deltaCore: DeltaCoreProtocol
    public var preferredRenderingSize: CGSize { return self.deltaCore.videoFormat.dimensions }
    
    //MARK: - Private Properties
    
    // We privately set this first to clean up before setting self.state, which notifies KVO observers
    private var _state = State.stopped
    
    private let gameType: GameType
    private let gameSaveURL: URL
    
    private var cheatCodes = [String: CheatType]()
    
    private var gameControllers = NSHashTable<AnyObject>.weakObjects()
    
    private var previousState = State.stopped
    private var previousFrameDuration: TimeInterval? = nil
    
    private var reactivateInputsDispatchGroup: DispatchGroup?
    private let reactivateInputsQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.EmulatorCore.reactivateInputsQueue", attributes: [.concurrent])
    
    private let emulationLock = NSLock()
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init?(game: GameProtocol)
    {
        // These MUST be set in start(), because it's possible the same emulator core might be stopped, another one started, and then resumed back to this one
        // AKA, these need to always be set at start to ensure it points to the correct managers
        // self.configuration.bridge.audioRenderer = self.audioManager
        // self.configuration.bridge.videoRenderer = self.videoManager
        
        guard let deltaCore = Delta.core(for: game.type) else {
            print(game.type.rawValue + " is not a supported game type.")
            return nil
        }
        
        self.deltaCore = deltaCore
        
        self.game = game
        
        // Store separately in case self.game is an NSManagedObject subclass, and we need to access .type or .gameSaveURL on a different thread than its NSManagedObjectContext
        self.gameType = self.game.type
        self.gameSaveURL = self.game.gameSaveURL
        
        // These were previously lazy variables, but turns out Swift lazy variables are not thread-safe.
        // Since they don't actually need to be lazy, we now explicitly initialize them in the initializer.
        self.audioManager = AudioManager(audioFormat: deltaCore.audioFormat)
        self.videoManager = VideoManager(videoFormat: deltaCore.videoFormat)
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(EmulatorCore.emulationDidQuit), name: EmulatorCore.emulationDidQuitNotification, object: nil)
    }
}

//MARK: - Emulation -
/// Emulation
public extension EmulatorCore
{
    @discardableResult func start() -> Bool
    {
        guard self._state == .stopped else { return false }
        
        self.emulationLock.lock()
        
        self._state = .running
        defer { self.state = self._state }
        
        self.deltaCore.emulatorBridge.audioRenderer = self.audioManager
        self.deltaCore.emulatorBridge.videoRenderer = self.videoManager
        self.deltaCore.emulatorBridge.saveUpdateHandler = { [unowned self] in
            self.save()
        }
        
        self.audioManager.start()
        self.deltaCore.emulatorBridge.start(withGameURL: self.game.fileURL)
        
        let videoFormat = self.deltaCore.videoFormat
        if videoFormat != self.videoManager.videoFormat
        {
            self.videoManager.videoFormat = videoFormat
        }
        
        self.deltaCore.emulatorBridge.loadGameSave(from: self.gameSaveURL)
        
        self.runGameLoop()
        self.waitForFrameUpdate()
        
        self.emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func stop() -> Bool
    {
        guard self._state != .stopped else { return false }
        
        self.emulationLock.lock()
        
        let isRunning = self.state == .running
        
        self._state = .stopped
        defer { self.state = self._state }
        
        if isRunning
        {
            self.waitForFrameUpdate()
        }
        
        self.save()
        
        self.audioManager.stop()
        self.deltaCore.emulatorBridge.stop()
        
        self.emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func pause() -> Bool
    {
        guard self._state == .running else { return false }
        
        self.emulationLock.lock()
        
        self._state = .paused
        defer { self.state = self._state }
        
        self.waitForFrameUpdate()
        
        self.save()
        
        self.audioManager.isEnabled = false
        self.deltaCore.emulatorBridge.pause()
        
        self.emulationLock.unlock()
        
        return true
    }
    
    @discardableResult func resume() -> Bool
    {
        guard self._state == .paused else { return false }
        
        self.emulationLock.lock()
        
        self._state = .running
        defer { self.state = self._state }
        
        self.audioManager.isEnabled = true
        self.deltaCore.emulatorBridge.resume()
        
        self.runGameLoop()
        self.waitForFrameUpdate()
        
        self.emulationLock.unlock()
        
        return true
    }
    
    private func waitForFrameUpdate()
    {
        let semaphore = DispatchSemaphore(value: 0)

        let token = NotificationCenter.default.addObserver(forName: EmulatorCore.didUpdateFrameNotification, object: self, queue: nil) { (notification) in
            semaphore.signal()
        }

        semaphore.wait()

        NotificationCenter.default.removeObserver(token, name: EmulatorCore.didUpdateFrameNotification, object: self)
    }
}

//MARK: - Game Views -
/// Game Views
public extension EmulatorCore
{
    func add(_ gameView: GameView)
    {
        self.gameViews.append(gameView)
        
        self.videoManager.add(gameView)
    }
    
    func remove(_ gameView: GameView)
    {
        if let index = self.gameViews.firstIndex(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
        
        self.videoManager.remove(gameView)
    }
}

//MARK: - Game Saves -
/// Game Saves
public extension EmulatorCore
{
    func save()
    {
        self.deltaCore.emulatorBridge.saveGameSave(to: self.gameSaveURL)
        self.saveHandler?(self)
    }
}

//MARK: - Save States -
/// Save States
public extension EmulatorCore
{
    @discardableResult func saveSaveState(to url: URL) -> SaveStateProtocol
    {
        self.deltaCore.emulatorBridge.saveSaveState(to: url)
        
        let saveState = SaveState(fileURL: url, gameType: self.gameType)
        return saveState
    }
    
    func load(_ saveState: SaveStateProtocol) throws
    {
        guard FileManager.default.fileExists(atPath: saveState.fileURL.path) else { throw SaveStateError.doesNotExist }
        
        self.deltaCore.emulatorBridge.loadSaveState(from: saveState.fileURL)
        
        self.updateCheats()
        self.deltaCore.emulatorBridge.resetInputs()
        
        // Reactivate activated inputs.
        for gameController in self.gameControllers.allObjects as! [GameController]
        {
            for (input, value) in gameController.activatedInputs
            {
                gameController.activate(input, value: value)
            }
        }
    }
}

//MARK: - Cheats -
/// Cheats
public extension EmulatorCore
{
    func activate(_ cheat: CheatProtocol) throws
    {
        let success = self.deltaCore.emulatorBridge.addCheatCode(String(cheat.code), type: cheat.type.rawValue)
        if success
        {
            self.cheatCodes[cheat.code] = cheat.type
        }
        
        // Ensures correct state, especially if attempted cheat was invalid
        self.updateCheats()
        
        if !success
        {
            throw CheatError.invalid
        }
    }
    
    func deactivate(_ cheat: CheatProtocol)
    {
        guard self.cheatCodes[cheat.code] != nil else { return }
        
        self.cheatCodes[cheat.code] = nil
        
        self.updateCheats()
    }
    
    private func updateCheats()
    {
        self.deltaCore.emulatorBridge.resetCheats()
        
        for (cheatCode, type) in self.cheatCodes
        {
            self.deltaCore.emulatorBridge.addCheatCode(String(cheatCode), type: type.rawValue)
        }
        
        self.deltaCore.emulatorBridge.updateCheats()
    }
}

extension EmulatorCore: GameControllerReceiver
{
    public func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        self.gameControllers.add(gameController)
        
        guard let input = self.mappedInput(for: input), input.type == .game(self.gameType) else { return }
        
        // If any of game controller's sustained inputs map to input, treat input as sustained.
        let isSustainedInput = gameController.sustainedInputs.keys.contains(where: {
            guard let mappedInput = gameController.mappedInput(for: $0, receiver: self) else { return false }
            return self.mappedInput(for: mappedInput) == input
        })
        
        if isSustainedInput && !input.isContinuous
        {
            self.reactivateInputsQueue.async {
                
                self.deltaCore.emulatorBridge.deactivateInput(input.intValue!)
                
                self.reactivateInputsDispatchGroup = DispatchGroup()
                
                // To ensure the emulator core recognizes us activating an input that is currently active, we need to first deactivate it, wait at least two frames, then activate it again.
                self.reactivateInputsDispatchGroup?.enter()
                self.reactivateInputsDispatchGroup?.enter()
                self.reactivateInputsDispatchGroup?.wait()

                self.reactivateInputsDispatchGroup = nil
                
                self.deltaCore.emulatorBridge.activateInput(input.intValue!, value: value)
            }
        }
        else
        {
            self.deltaCore.emulatorBridge.activateInput(input.intValue!, value: value)
        }
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        guard let input = self.mappedInput(for: input), input.type == .game(self.gameType) else { return }
        
        self.deltaCore.emulatorBridge.deactivateInput(input.intValue!)
    }
    
    private func mappedInput(for input: Input) -> Input?
    {
        guard let standardInput = StandardGameControllerInput(input: input) else { return input }
        
        let mappedInput = standardInput.input(for: self.gameType)
        return mappedInput
    }
}

private extension EmulatorCore
{
    func runGameLoop()
    {
        let emulationQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.emulationQueue", qos: .userInitiated)
        emulationQueue.async {
            
            let screenRefreshRate = 1.0 / 60.0
            
            var emulationTime = Thread.absoluteSystemTime
            var counter = 0.0
            
            while true
            {
                let frameDuration = self.deltaCore.emulatorBridge.frameDuration / self.rate
                if frameDuration != self.previousFrameDuration
                {
                    Thread.setRealTimePriority(withPeriod: frameDuration)
                    
                    self.previousFrameDuration = frameDuration
                    
                    // Reset counter
                    counter = 0
                }
                
                // Update audio/video configurations if necessary.
                
                let internalFrameDuration = self.deltaCore.emulatorBridge.frameDuration
                if internalFrameDuration != self.audioManager.frameDuration
                {
                    self.audioManager.frameDuration = internalFrameDuration
                }
                
                let audioFormat = self.deltaCore.audioFormat
                if audioFormat != self.audioManager.audioFormat
                {
                    self.audioManager.audioFormat = audioFormat
                }
                
                let videoFormat = self.deltaCore.videoFormat
                if videoFormat != self.videoManager.videoFormat
                {
                    self.videoManager.videoFormat = videoFormat
                }
                
                if counter >= screenRefreshRate
                {
                    self.runFrame(renderGraphics: true)
                    
                    // Reset counter
                    counter = 0
                }
                else
                {
                    // No need to render graphics more than once per screen refresh rate
                    self.runFrame(renderGraphics: false)
                }
                
                counter += frameDuration
                emulationTime += frameDuration
                
                let currentTime = Thread.absoluteSystemTime
                
                // The number of frames we need to skip to keep in sync
                var framesToSkip = Int((currentTime - emulationTime) / frameDuration)
                framesToSkip = min(framesToSkip, 5) // Prevent unbounding frame skipping resulting in frozen game.
                
                if framesToSkip > 0
                {
                    // Only actually skip frames if we're running at normal speed
                    if self.rate == 1.0
                    {
                        for _ in 0 ..< framesToSkip
                        {
                            // "Skip" frames by running them without rendering graphics
                            self.runFrame(renderGraphics: false)
                        }
                    }
                    
                    emulationTime = currentTime
                }
                
                // Prevent race conditions
                let state = self._state
                
                defer
                {                    
                    if self.previousState != state
                    {
                        NotificationCenter.default.post(name: EmulatorCore.didUpdateFrameNotification, object: self)
                        self.previousState = state
                    }
                }
                
                if state != .running
                {
                    break
                }
                
                Thread.realTimeWait(until: emulationTime)
            }
        }
    }
    
    func runFrame(renderGraphics: Bool)
    {
        self.deltaCore.emulatorBridge.runFrame(processVideo: renderGraphics)
        
        if renderGraphics
        {
            self.videoManager.render()
        }
        
        if let dispatchGroup = self.reactivateInputsDispatchGroup
        {
            dispatchGroup.leave()
        }
        
        self.updateHandler?(self)
    }
}

private extension EmulatorCore
{
    @objc func emulationDidQuit(_ notification: Notification)
    {
        DispatchQueue.global(qos: .userInitiated).async {
            // Dispatch onto global queue to prevent deadlock.
            self.stop()
        }
    }
}
