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
        for controller in ExternalGameControllerManager.shared.connectedControllers {
            if let mfi = controller as? MFiGameController, mfi.controller.extendedGamepad == nil {
                continue
            }
            controller.addReceiver(emulator)
        }
    }
    
    @objc private func controllersChanged() {
        self.connectControllers()
    }
    
    // MARK: - Siri Remote Menu Interception
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                // Intercept Menu button to toggle Pause Menu
                self.showPauseMenu()
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
    
    private func showPauseMenu() {
        guard let emulator = self.emulatorCore else { return }
        emulator.pause()
        self.isPaused = true
        
        let alert = UIAlertController(title: "Paused: \(self.game.name)", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Resume", style: .default, handler: { [weak self] _ in
            self?.emulatorCore?.resume()
            self?.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Save State", style: .default, handler: { [weak self] _ in
            guard let self = self, let emulator = self.emulatorCore else { return }
            let saveStateURL = self.game.fileURL.deletingPathExtension().appendingPathExtension("savestate")
            _ = emulator.saveSaveState(to: saveStateURL)
            emulator.resume()
            self.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Load State", style: .default, handler: { [weak self] _ in
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
        
        alert.addAction(UIAlertAction(title: "Restart Game", style: .destructive, handler: { [weak self] _ in
            guard let self = self, let emulator = self.emulatorCore else { return }
            emulator.stop()
            emulator.start()
            self.isPaused = false
        }))
        
        alert.addAction(UIAlertAction(title: "Quit to Library", style: .destructive, handler: { [weak self] _ in
            self?.emulatorCore?.stop()
            self?.onDismiss?()
        }))
        
        self.present(alert, animated: true)
    }
}
