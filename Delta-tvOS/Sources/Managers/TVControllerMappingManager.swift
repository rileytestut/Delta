import Foundation
import GameController
import DeltaCore
import NESDeltaCore
import SNESDeltaCore
import N64DeltaCore

/// Represents a physical button or direction on an MFi / Xbox / PlayStation / Switch gamepad
enum TVGamepadButton: String, CaseIterable, Identifiable, Codable {
    case a = "a"
    case b = "b"
    case x = "x"
    case y = "y"
    case leftShoulder = "leftShoulder"       // L1 / LB
    case rightShoulder = "rightShoulder"     // R1 / RB
    case leftTrigger = "leftTrigger"         // L2 / LT
    case rightTrigger = "rightTrigger"       // R2 / RT
    case start = "start"                     // Start / Menu
    case select = "select"                   // Select / Options / Back
    case menu = "menu"                       // Secondary Menu / Xbox / PS button
    case up = "up"                           // D-Pad Up
    case down = "down"                       // D-Pad Down
    case left = "left"                       // D-Pad Left
    case right = "right"                     // D-Pad Right
    case rightThumbstickUp = "rightThumbstickUp"
    case rightThumbstickDown = "rightThumbstickDown"
    case rightThumbstickLeft = "rightThumbstickLeft"
    case rightThumbstickRight = "rightThumbstickRight"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .leftShoulder: return "L1 / LB"
        case .rightShoulder: return "R1 / RB"
        case .leftTrigger: return "L2 / LT"
        case .rightTrigger: return "R2 / RT"
        case .start: return "Start / +"
        case .select: return "Select / -"
        case .menu: return "Menu"
        case .up: return "D-Pad Ylös"
        case .down: return "D-Pad Alas"
        case .left: return "D-Pad Vasen"
        case .right: return "D-Pad Oikea"
        case .rightThumbstickUp: return "Oikea Tatti Ylös"
        case .rightThumbstickDown: return "Oikea Tatti Alas"
        case .rightThumbstickLeft: return "Oikea Tatti Vasen"
        case .rightThumbstickRight: return "Oikea Tatti Oikea"
        }
    }
}

/// Represents a console action for a specific system (N64, SNES, NES)
struct TVConsoleAction: Identifiable, Hashable {
    let id: String
    let displayName: String
    let system: TVSystem
    let category: String
}

class TVControllerMappingManager: ObservableObject {
    static let shared = TVControllerMappingManager()
    
    @Published var mappings: [TVSystem: [String: TVGamepadButton]] = [:]
    @Published var listeningAction: TVConsoleAction? = nil
    
    var lastGamepadInteractionTime: Double = 0
    private var listeningTimer: Timer?
    
    private init() {
        self.loadMappings()
        self.configureControllers()
        
        NotificationCenter.default.addObserver(self, selector: #selector(controllersChanged), name: .GCControllerDidConnect, object: nil)
    }
    
    @objc private func controllersChanged() {
        self.configureControllers()
    }
    
    /// Configures connected physical controllers to disable system gestures so tvOS won't capture Menu/Back
    func configureControllers() {
        for controller in GCController.controllers() {
            let profile = controller.physicalInputProfile
            profile.buttons[GCInputButtonMenu]?.preferredSystemGestureState = .disabled
            profile.buttons[GCInputButtonOptions]?.preferredSystemGestureState = .disabled
            profile.buttons[GCInputButtonHome]?.preferredSystemGestureState = .disabled
        }
    }
    
    // MARK: - Supported Actions per System
    
    func supportedActions(for system: TVSystem) -> [TVConsoleAction] {
        switch system {
        case .n64:
            return [
                TVConsoleAction(id: "start", displayName: "Start-nappi", system: .n64, category: "Päätoiminnot"),
                TVConsoleAction(id: "a", displayName: "A-nappi", system: .n64, category: "Päätoiminnot"),
                TVConsoleAction(id: "b", displayName: "B-nappi", system: .n64, category: "Päätoiminnot"),
                TVConsoleAction(id: "z", displayName: "Z-liipaisin", system: .n64, category: "Liipaisimet"),
                TVConsoleAction(id: "l", displayName: "L-olkanappi", system: .n64, category: "Liipaisimet"),
                TVConsoleAction(id: "r", displayName: "R-olkanappi", system: .n64, category: "Liipaisimet"),
                TVConsoleAction(id: "cUp", displayName: "C-Ylös", system: .n64, category: "C-napit"),
                TVConsoleAction(id: "cDown", displayName: "C-Alas", system: .n64, category: "C-napit"),
                TVConsoleAction(id: "cLeft", displayName: "C-Vasen", system: .n64, category: "C-napit"),
                TVConsoleAction(id: "cRight", displayName: "C-Oikea", system: .n64, category: "C-napit"),
                TVConsoleAction(id: "up", displayName: "Ristiohjain Ylös", system: .n64, category: "Ristiohjain"),
                TVConsoleAction(id: "down", displayName: "Ristiohjain Alas", system: .n64, category: "Ristiohjain"),
                TVConsoleAction(id: "left", displayName: "Ristiohjain Vasen", system: .n64, category: "Ristiohjain"),
                TVConsoleAction(id: "right", displayName: "Ristiohjain Oikea", system: .n64, category: "Ristiohjain")
            ]
        case .snes:
            return [
                TVConsoleAction(id: "a", displayName: "A-nappi", system: .snes, category: "Toimintonapit"),
                TVConsoleAction(id: "b", displayName: "B-nappi", system: .snes, category: "Toimintonapit"),
                TVConsoleAction(id: "x", displayName: "X-nappi", system: .snes, category: "Toimintonapit"),
                TVConsoleAction(id: "y", displayName: "Y-nappi", system: .snes, category: "Toimintonapit"),
                TVConsoleAction(id: "start", displayName: "Start-nappi", system: .snes, category: "Valikkonapit"),
                TVConsoleAction(id: "select", displayName: "Select-nappi", system: .snes, category: "Valikkonapit"),
                TVConsoleAction(id: "l", displayName: "L-olkanappi", system: .snes, category: "Olkanapit"),
                TVConsoleAction(id: "r", displayName: "R-olkanappi", system: .snes, category: "Olkanapit"),
                TVConsoleAction(id: "up", displayName: "Ristiohjain Ylös", system: .snes, category: "Ristiohjain"),
                TVConsoleAction(id: "down", displayName: "Ristiohjain Alas", system: .snes, category: "Ristiohjain"),
                TVConsoleAction(id: "left", displayName: "Ristiohjain Vasen", system: .snes, category: "Ristiohjain"),
                TVConsoleAction(id: "right", displayName: "Ristiohjain Oikea", system: .snes, category: "Ristiohjain")
            ]
        case .nes:
            return [
                TVConsoleAction(id: "a", displayName: "A-nappi", system: .nes, category: "Toimintonapit"),
                TVConsoleAction(id: "b", displayName: "B-nappi", system: .nes, category: "Toimintonapit"),
                TVConsoleAction(id: "start", displayName: "Start-nappi", system: .nes, category: "Valikkonapit"),
                TVConsoleAction(id: "select", displayName: "Select-nappi", system: .nes, category: "Valikkonapit"),
                TVConsoleAction(id: "up", displayName: "Ristiohjain Ylös", system: .nes, category: "Ristiohjain"),
                TVConsoleAction(id: "down", displayName: "Ristiohjain Alas", system: .nes, category: "Ristiohjain"),
                TVConsoleAction(id: "left", displayName: "Ristiohjain Vasen", system: .nes, category: "Ristiohjain"),
                TVConsoleAction(id: "right", displayName: "Ristiohjain Oikea", system: .nes, category: "Ristiohjain")
            ]
        }
    }
    
    // MARK: - Default Mappings
    
    func defaultMapping(for system: TVSystem) -> [String: TVGamepadButton] {
        switch system {
        case .n64:
            return [
                "start": .start,
                "a": .a,
                "b": .b,
                "z": .leftTrigger,
                "l": .leftShoulder,
                "r": .rightShoulder,
                "cUp": .rightThumbstickUp,
                "cDown": .rightThumbstickDown,
                "cLeft": .rightThumbstickLeft,
                "cRight": .rightThumbstickRight,
                "up": .up,
                "down": .down,
                "left": .left,
                "right": .right
            ]
        case .snes:
            return [
                "a": .a,
                "b": .b,
                "x": .x,
                "y": .y,
                "start": .start,
                "select": .select,
                "l": .leftShoulder,
                "r": .rightShoulder,
                "up": .up,
                "down": .down,
                "left": .left,
                "right": .right
            ]
        case .nes:
            return [
                "a": .a,
                "b": .b,
                "start": .start,
                "select": .select,
                "up": .up,
                "down": .down,
                "left": .left,
                "right": .right
            ]
        }
    }
    
    // MARK: - Persistence
    
    func mappedButton(for action: TVConsoleAction) -> TVGamepadButton? {
        return self.mappings[action.system]?[action.id] ?? self.defaultMapping(for: action.system)[action.id]
    }
    
    func setMapping(_ button: TVGamepadButton, for action: TVConsoleAction) {
        var systemMap = self.mappings[action.system] ?? self.defaultMapping(for: action.system)
        systemMap[action.id] = button
        self.mappings[action.system] = systemMap
        self.saveMappings()
    }
    
    func resetToDefaults(for system: TVSystem) {
        self.mappings[system] = self.defaultMapping(for: system)
        self.saveMappings()
    }
    
    private func saveMappings() {
        for system in TVSystem.allCases {
            if let map = self.mappings[system] {
                let stringMap = map.mapValues { $0.rawValue }
                UserDefaults.standard.set(stringMap, forKey: "TVControllerMapping_\(system.rawValue)")
            }
        }
    }
    
    private func loadMappings() {
        for system in TVSystem.allCases {
            if let dict = UserDefaults.standard.dictionary(forKey: "TVControllerMapping_\(system.rawValue)") as? [String: String] {
                var map: [String: TVGamepadButton] = [:]
                for (k, v) in dict {
                    if let btn = TVGamepadButton(rawValue: v) {
                        map[k] = btn
                    }
                }
                self.mappings[system] = map
            } else {
                self.mappings[system] = self.defaultMapping(for: system)
            }
        }
    }
    
    // MARK: - Interactive Gamepad Input Listener
    
    func startListening(for action: TVConsoleAction, completion: @escaping (TVGamepadButton) -> Void) {
        self.listeningAction = action
        self.configureControllers()
        
        let controllers = GCController.controllers().filter { $0.extendedGamepad != nil }
        guard !controllers.isEmpty else { return }
        
        // Listen on all extended gamepads
        for controller in controllers {
            guard let extended = controller.extendedGamepad else { continue }
            
            let handleButton: (TVGamepadButton) -> Void = { [weak self] button in
                guard let self = self, self.listeningAction?.id == action.id else { return }
                self.stopListening()
                self.setMapping(button, for: action)
                completion(button)
            }
            
            extended.buttonA.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.a) } }
            extended.buttonB.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.b) } }
            extended.buttonX.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.x) } }
            extended.buttonY.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.y) } }
            
            extended.leftShoulder.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.leftShoulder) } }
            extended.rightShoulder.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightShoulder) } }
            extended.leftTrigger.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.leftTrigger) } }
            extended.rightTrigger.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightTrigger) } }
            
            extended.buttonMenu.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.start) } }
            extended.buttonOptions?.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.select) } }
            extended.buttonHome?.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.menu) } }
            
            extended.dpad.up.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.up) } }
            extended.dpad.down.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.down) } }
            extended.dpad.left.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.left) } }
            extended.dpad.right.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.right) } }
            
            extended.rightThumbstick.up.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightThumbstickUp) } }
            extended.rightThumbstick.down.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightThumbstickDown) } }
            extended.rightThumbstick.left.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightThumbstickLeft) } }
            extended.rightThumbstick.right.pressedChangedHandler = { _, _, pressed in if pressed { handleButton(.rightThumbstickRight) } }
        }
    }
    
    func stopListening() {
        self.listeningAction = nil
        // Restore normal controller handlers
        NotificationCenter.default.post(name: .GCControllerDidConnect, object: nil)
    }
    
    // MARK: - DeltaCore GameControllerInputMapping Generator
    
    func createDeltaInputMapping(for system: TVSystem) -> GameControllerInputMapping {
        var deltaMapping = GameControllerInputMapping(gameControllerInputType: .mfi)
        let systemMap = self.mappings[system] ?? self.defaultMapping(for: system)
        
        for (actionId, gamepadBtn) in systemMap {
            let mfiInput = AnyInput(stringValue: gamepadBtn.rawValue, intValue: nil, type: .controller(.mfi))
            let consoleInput = self.consoleInput(for: actionId, system: system)
            if let consoleInput = consoleInput {
                deltaMapping.set(consoleInput, forControllerInput: mfiInput)
            }
        }
        
        // Also map secondary buttons (e.g. Start on physical buttonMenu, buttonOptions, buttonX)
        if system == .n64 {
            // Analog stick always maps directly from left thumbstick
            deltaMapping.set(N64GameInput.analogStickUp, forControllerInput: MFiGameController.Input.leftThumbstickUp)
            deltaMapping.set(N64GameInput.analogStickDown, forControllerInput: MFiGameController.Input.leftThumbstickDown)
            deltaMapping.set(N64GameInput.analogStickLeft, forControllerInput: MFiGameController.Input.leftThumbstickLeft)
            deltaMapping.set(N64GameInput.analogStickRight, forControllerInput: MFiGameController.Input.leftThumbstickRight)
        } else if system == .snes {
            deltaMapping.set(SNESGameInput.up, forControllerInput: MFiGameController.Input.leftThumbstickUp)
            deltaMapping.set(SNESGameInput.down, forControllerInput: MFiGameController.Input.leftThumbstickDown)
            deltaMapping.set(SNESGameInput.left, forControllerInput: MFiGameController.Input.leftThumbstickLeft)
            deltaMapping.set(SNESGameInput.right, forControllerInput: MFiGameController.Input.leftThumbstickRight)
        } else if system == .nes {
            deltaMapping.set(NESGameInput.up, forControllerInput: MFiGameController.Input.leftThumbstickUp)
            deltaMapping.set(NESGameInput.down, forControllerInput: MFiGameController.Input.leftThumbstickDown)
            deltaMapping.set(NESGameInput.left, forControllerInput: MFiGameController.Input.leftThumbstickLeft)
            deltaMapping.set(NESGameInput.right, forControllerInput: MFiGameController.Input.leftThumbstickRight)
        }
        
        return deltaMapping
    }
    
    private func consoleInput(for actionId: String, system: TVSystem) -> Input? {
        switch system {
        case .n64:
            switch actionId {
            case "a": return N64GameInput.a
            case "b": return N64GameInput.b
            case "z": return N64GameInput.z
            case "start": return N64GameInput.start
            case "l": return N64GameInput.l
            case "r": return N64GameInput.r
            case "cUp": return N64GameInput.cUp
            case "cDown": return N64GameInput.cDown
            case "cLeft": return N64GameInput.cLeft
            case "cRight": return N64GameInput.cRight
            case "up": return N64GameInput.up
            case "down": return N64GameInput.down
            case "left": return N64GameInput.left
            case "right": return N64GameInput.right
            default: return nil
            }
        case .snes:
            switch actionId {
            case "a": return SNESGameInput.a
            case "b": return SNESGameInput.b
            case "x": return SNESGameInput.x
            case "y": return SNESGameInput.y
            case "start": return SNESGameInput.start
            case "select": return SNESGameInput.select
            case "l": return SNESGameInput.l
            case "r": return SNESGameInput.r
            case "up": return SNESGameInput.up
            case "down": return SNESGameInput.down
            case "left": return SNESGameInput.left
            case "right": return SNESGameInput.right
            default: return nil
            }
        case .nes:
            switch actionId {
            case "a": return NESGameInput.a
            case "b": return NESGameInput.b
            case "start": return NESGameInput.start
            case "select": return NESGameInput.select
            case "up": return NESGameInput.up
            case "down": return NESGameInput.down
            case "left": return NESGameInput.left
            case "right": return NESGameInput.right
            default: return nil
            }
        }
    }
}
