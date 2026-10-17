import UIKit
import SwiftUI
import DeltaCore
import GameController

class GameEmulatorViewController: UIViewController {
    let game: TVGame
    
    private var emulatorCore: EmulatorCore?
    private var gameView: GameView!
    private var isPaused = false
    
    var onDismiss: (() -> Void)?
    
    init(game: TVGame) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        
        // 1. Setup GameView
        self.gameView = GameView(frame: self.view.bounds)
        self.gameView.backgroundColor = .black
        self.gameView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.gameView)
        
        NSLayoutConstraint.activate([
            self.gameView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.gameView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.gameView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.gameView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        // 2. Initialize EmulatorCore
        guard let emulator = EmulatorCore(game: self.game.deltaGame) else {
            let alert = UIAlertController(title: "Emulation Error", message: "Failed to initialize emulator core for \(game.name).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Back", style: .default, handler: { [weak self] _ in
                self?.onDismiss?()
            }))
            self.present(alert, animated: true)
            return
        }
        
        self.emulatorCore = emulator
        emulator.add(self.gameView)
        
        // 3. Connect Game Controllers
        self.connectControllers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(controllersChanged), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllersChanged), name: .GCControllerDidDisconnect, object: nil)
        
        // 4. Start Emulation
        emulator.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.emulatorCore?.stop()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.emulatorCore?.stop()
    }
    
    private func connectControllers() {
        guard let emulator = self.emulatorCore else { return }
        let mapping = TVControllerMappingManager.shared.createDeltaInputMapping(for: self.game.system)
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            if let mfi = controller as? MFiGameController, mfi.controller.extendedGamepad == nil {
                continue
            }
            controller.addReceiver(emulator, inputMapping: mapping)
        }
    }
    
    @objc private func controllersChanged() {
        self.connectControllers()
    }
    
    override var canBecomeFirstResponder: Bool { true }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
    
    // MARK: - Controller Press Interception
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                // If this event came from a physical gamepad, ignore it!
                let isGamepadActive = GCController.controllers().contains { controller in
                    guard let ext = controller.extendedGamepad else { return false }
                    return ext.buttonMenu.isPressed ||
                           ext.buttonOptions?.isPressed == true ||
                           ext.buttonHome?.isPressed == true ||
                           ext.buttonB.isPressed ||
                           ext.buttonA.isPressed ||
                           ext.buttonX.isPressed ||
                           ext.buttonY.isPressed
                }
                
                if isGamepadActive {
                    return
                }
                
                // Intercept Menu button exclusively from Apple TV Siri Remote
                self.showPauseMenu()
                return
            }
        }
        // DO NOT call super! This prevents Gamepad A (.select) from dismissing the game or triggering background actions.
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    
    private func showPauseMenu() {
        guard let emulator = self.emulatorCore else { return }
        emulator.pause()
        self.isPaused = true
        
        let alert = UIAlertController(title: "Pysäytetty: \(self.game.name)", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Jatka peliä", style: .default, handler: { [weak self] _ in
            self?.emulatorCore?.resume()
            self?.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Määritä ohjaimen napit (Remap)", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let remapView = ControllerRemapView(initialSystem: self.game.system) { [weak self] in
                self?.connectControllers()
                self?.showPauseMenu()
            }
            let hosting = UIHostingController(rootView: remapView)
            hosting.modalPresentationStyle = .overFullScreen
            self.present(hosting, animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Tallenna tilanne (Save State)", style: .default, handler: { [weak self] _ in
            guard let self = self, let emulator = self.emulatorCore else { return }
            let saveStateURL = self.game.fileURL.deletingPathExtension().appendingPathExtension("savestate")
            _ = emulator.saveSaveState(to: saveStateURL)
            emulator.resume()
            self.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Lataa tilanne (Load State)", style: .default, handler: { [weak self] _ in
            guard let self = self, let emulator = self.emulatorCore else { return }
            let saveStateURL = self.game.fileURL.deletingPathExtension().appendingPathExtension("savestate")
            if FileManager.default.fileExists(atPath: saveStateURL.path) {
                let saveState = SaveState(fileURL: saveStateURL, gameType: self.game.system.gameType)
                do {
                    try emulator.load(saveState)
                } catch {
                    print("Failed to load state: \(error)")
                }
            }
            emulator.resume()
            self.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Käynnistä peli alusta", style: .destructive, handler: { [weak self] _ in
            guard let self = self, let emulator = self.emulatorCore else { return }
            emulator.stop()
            emulator.start()
            self.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Lopeta kirjastoon", style: .destructive, handler: { [weak self] _ in
            self?.emulatorCore?.stop()
            self?.dismiss(animated: true) {
                self?.onDismiss?()
            }
        }))
        
        self.present(alert, animated: true)
    }
    
    private func showControllerLayoutInfo() {
        let title = "\(self.game.system.shortName) Controller Mapping"
        let message: String
        switch self.game.system {
        case .n64:
            message = """
            • A Button ➔ A
            • B Button ➔ B
            • Z Trigger ➔ L2 / R2 (or Y / Select)
            • Start Button ➔ Start / Menu / Options (or X)
            • L / R Bumpers ➔ L1 / R1
            • C-Buttons (Yellow) ➔ Right Thumbstick
            • Analog Stick ➔ Left Thumbstick
            • D-Pad ➔ D-Pad
            """
        case .snes:
            message = """
            • A, B, X, Y ➔ A, B, X, Y
            • L / R Shoulders ➔ L1 / R1
            • Start ➔ Start / Menu
            • Select ➔ Select / Options
            • D-Pad ➔ D-Pad / Left Stick
            """
        case .nes:
            message = """
            • A, B ➔ A, B
            • Start ➔ Start / Menu
            • Select ➔ Select / Options
            • D-Pad ➔ D-Pad / Left Stick
            """
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.showPauseMenu()
        }))
        self.present(alert, animated: true)
    }
}
