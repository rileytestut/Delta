import Foundation
import GameController
import CoreHaptics
import DeltaCore
import NESDeltaCore
import SNESDeltaCore
import N64DeltaCore
import GBCDeltaCore
import GBADeltaCore
import GPGXDeltaCore
import MelonDSDeltaCore

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
    
    func value(in pad: GCExtendedGamepad) -> Float {
        switch self {
        case .a: return pad.buttonA.value
        case .b: return pad.buttonB.value
        case .x: return pad.buttonX.value
        case .y: return pad.buttonY.value
        case .leftShoulder: return pad.leftShoulder.value
        case .rightShoulder: return pad.rightShoulder.value
        case .leftTrigger: return pad.leftTrigger.value
        case .rightTrigger: return pad.rightTrigger.value
        case .start: return pad.buttonMenu.value
        case .select: return pad.buttonOptions?.value ?? 0
        case .menu: return pad.buttonHome?.value ?? 0
        case .up: return pad.dpad.up.value
        case .down: return pad.dpad.down.value
        case .left: return pad.dpad.left.value
        case .right: return pad.dpad.right.value
        case .rightThumbstickUp: return pad.rightThumbstick.up.value
        case .rightThumbstickDown: return pad.rightThumbstick.down.value
        case .rightThumbstickLeft: return pad.rightThumbstick.left.value
        case .rightThumbstickRight: return pad.rightThumbstick.right.value
        }
    }

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
        case .up: return "D-Pad Up"
        case .down: return "D-Pad Down"
        case .left: return "D-Pad Left"
        case .right: return "D-Pad Right"
        case .rightThumbstickUp: return "Right Stick Up"
        case .rightThumbstickDown: return "Right Stick Down"
        case .rightThumbstickLeft: return "Right Stick Left"
        case .rightThumbstickRight: return "Right Stick Right"
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
    @Published private(set) var capturedButton: TVGamepadButton?
    @Published var hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: "TVMappingHapticFeedback") {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "TVMappingHapticFeedback") }
    }
    private var feedbackEngine: CHHapticEngine?
    private var feedbackControllerID: ObjectIdentifier?
    
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
        for controller in GCController.controllers() where controller.extendedGamepad != nil {
            let profile = controller.physicalInputProfile
            profile.buttons[GCInputButtonMenu]?.preferredSystemGestureState = .disabled
            profile.buttons[GCInputButtonOptions]?.preferredSystemGestureState = .disabled
            profile.buttons[GCInputButtonHome]?.preferredSystemGestureState = .disabled
        }
    }
    
    // MARK: - Supported Actions per System
    
    func supportedActions(for system: TVSystem) -> [TVConsoleAction] {
        switch system {
        case .gbc, .gba, .genesis, .ds:
            let ids: [String]
            switch system {
            case .gbc: ids = ["a", "b", "start", "select", "up", "down", "left", "right"]
            case .gba: ids = ["a", "b", "l", "r", "start", "select", "up", "down", "left", "right"]
            case .genesis: ids = ["a", "b", "c", "x", "y", "z", "start", "mode", "up", "down", "left", "right"]
            default: ids = ["a", "b", "x", "y", "l", "r", "start", "select", "lid", "touch", "up", "down", "left", "right"]
            }
            return ids.map { id in
                let names = ["touch": "Touch (move pointer with right stick)", "lid": "Close Lid", "mode": "Mode"]
                return TVConsoleAction(id: id, displayName: names[id] ?? id.uppercased(), system: system, category: "Controls")
            }
        case .n64:
            return [
                TVConsoleAction(id: "start", displayName: "Start Button", system: .n64, category: "Main Controls"),
                TVConsoleAction(id: "a", displayName: "A Button", system: .n64, category: "Main Controls"),
                TVConsoleAction(id: "b", displayName: "B Button", system: .n64, category: "Main Controls"),
                TVConsoleAction(id: "z", displayName: "Z Trigger", system: .n64, category: "Triggers"),
                TVConsoleAction(id: "l", displayName: "L Shoulder", system: .n64, category: "Triggers"),
                TVConsoleAction(id: "r", displayName: "R Shoulder", system: .n64, category: "Triggers"),
                TVConsoleAction(id: "cUp", displayName: "C-Up", system: .n64, category: "C Buttons"),
                TVConsoleAction(id: "cDown", displayName: "C-Down", system: .n64, category: "C Buttons"),
                TVConsoleAction(id: "cLeft", displayName: "C-Left", system: .n64, category: "C Buttons"),
                TVConsoleAction(id: "cRight", displayName: "C-Right", system: .n64, category: "C Buttons"),
                TVConsoleAction(id: "up", displayName: "D-Pad Up", system: .n64, category: "D-Pad"),
                TVConsoleAction(id: "down", displayName: "D-Pad Down", system: .n64, category: "D-Pad"),
                TVConsoleAction(id: "left", displayName: "D-Pad Left", system: .n64, category: "D-Pad"),
                TVConsoleAction(id: "right", displayName: "D-Pad Right", system: .n64, category: "D-Pad")
            ]
        case .snes:
            return [
                TVConsoleAction(id: "a", displayName: "A Button", system: .snes, category: "Action Buttons"),
                TVConsoleAction(id: "b", displayName: "B Button", system: .snes, category: "Action Buttons"),
                TVConsoleAction(id: "x", displayName: "X Button", system: .snes, category: "Action Buttons"),
                TVConsoleAction(id: "y", displayName: "Y Button", system: .snes, category: "Action Buttons"),
                TVConsoleAction(id: "start", displayName: "Start Button", system: .snes, category: "Menu Buttons"),
                TVConsoleAction(id: "select", displayName: "Select Button", system: .snes, category: "Menu Buttons"),
                TVConsoleAction(id: "l", displayName: "L Shoulder", system: .snes, category: "Shoulder Buttons"),
                TVConsoleAction(id: "r", displayName: "R Shoulder", system: .snes, category: "Shoulder Buttons"),
                TVConsoleAction(id: "up", displayName: "D-Pad Up", system: .snes, category: "D-Pad"),
                TVConsoleAction(id: "down", displayName: "D-Pad Down", system: .snes, category: "D-Pad"),
                TVConsoleAction(id: "left", displayName: "D-Pad Left", system: .snes, category: "D-Pad"),
                TVConsoleAction(id: "right", displayName: "D-Pad Right", system: .snes, category: "D-Pad")
            ]
        case .nes:
            return [
                TVConsoleAction(id: "a", displayName: "A Button", system: .nes, category: "Action Buttons"),
                TVConsoleAction(id: "b", displayName: "B Button", system: .nes, category: "Action Buttons"),
                TVConsoleAction(id: "start", displayName: "Start Button", system: .nes, category: "Menu Buttons"),
                TVConsoleAction(id: "select", displayName: "Select Button", system: .nes, category: "Menu Buttons"),
                TVConsoleAction(id: "up", displayName: "D-Pad Up", system: .nes, category: "D-Pad"),
                TVConsoleAction(id: "down", displayName: "D-Pad Down", system: .nes, category: "D-Pad"),
                TVConsoleAction(id: "left", displayName: "D-Pad Left", system: .nes, category: "D-Pad"),
                TVConsoleAction(id: "right", displayName: "D-Pad Right", system: .nes, category: "D-Pad")
            ]
        }
    }
    
    // MARK: - Default Mappings
    
    func defaultMapping(for system: TVSystem) -> [String: TVGamepadButton] {
        switch system {
        case .gbc:
            return self.defaultMapping(for: .nes)
        case .gba:
            var map = self.defaultMapping(for: .nes)
            map["l"] = .leftShoulder
            map["r"] = .rightShoulder
            return map
        case .genesis:
            return ["a": .x, "b": .a, "c": .b, "x": .leftShoulder, "y": .y, "z": .rightShoulder,
                    "start": .start, "mode": .select, "up": .up, "down": .down, "left": .left, "right": .right]
        case .ds:
            var map = self.defaultMapping(for: .snes)
            map["lid"] = .leftTrigger
            map["touch"] = .rightTrigger
            return map
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
        let previousButton = systemMap[action.id]
        // One physical input has one destination in Delta's mapping. Swap an
        // existing assignment instead of silently overwriting it during creation.
        for (id, mappedButton) in systemMap where id != action.id && mappedButton == button {
            systemMap[id] = previousButton
        }
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
        self.stopListening()
        self.listeningAction = action
        self.configureControllers()

        // Poll the extended profile without replacing DeltaCore's input handlers.
        // Ignore the button used to open the row until it has been released.
        func pressedButtons() -> [(String, TVGamepadButton)] {
            var result: [(String, TVGamepadButton)] = []
            for controller in GCController.controllers() {
                guard let pad = controller.extendedGamepad else { continue }
                let buttons: [(TVGamepadButton, GCControllerButtonInput?)] = [
                    (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
                    (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
                    (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
                    (.start, pad.buttonMenu), (.select, pad.buttonOptions), (.menu, pad.buttonHome),
                    (.up, pad.dpad.up), (.down, pad.dpad.down),
                    (.left, pad.dpad.left), (.right, pad.dpad.right),
                    (.rightThumbstickUp, pad.rightThumbstick.up),
                    (.rightThumbstickDown, pad.rightThumbstick.down),
                    (.rightThumbstickLeft, pad.rightThumbstick.left),
                    (.rightThumbstickRight, pad.rightThumbstick.right)
                ]
                for (button, input) in buttons where (input?.value ?? 0) > 0.5 {
                    result.append(("\(ObjectIdentifier(controller))-\(button.rawValue)", button))
                }
            }
            return result
        }
        var capture = ButtonCaptureState<String, TVGamepadButton>(initiallyPressed: pressedButtons().map { $0.0 })
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.listeningAction == action else { return }
            switch capture.sample(pressedButtons()) {
            case .detected(let button):
                self.capturedButton = button
            case .completed(let button):
                self.setMapping(button, for: action)
                self.stopListening()
                if let controller = GCController.controllers().first(where: {
                    capture.capturedKey == "\(ObjectIdentifier($0))-\(button.rawValue)"
                }) {
                    self.playMappingFeedback(on: controller)
                }
                completion(button)
            case nil:
                break
            }
        }
        self.listeningTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopListening() {
        self.listeningTimer?.invalidate()
        self.listeningTimer = nil
        self.listeningAction = nil
        self.capturedButton = nil
    }

    private func playMappingFeedback(on controller: GCController) {
        guard hapticFeedbackEnabled, let haptics = controller.haptics else { return }
        do {
            if feedbackControllerID != ObjectIdentifier(controller) || feedbackEngine == nil {
                feedbackEngine?.stop(completionHandler: nil)
                feedbackEngine = haptics.createEngine(withLocality: .default)
                feedbackControllerID = ObjectIdentifier(controller)
            }
            guard let engine = feedbackEngine else { return }
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0, duration: 0.08)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            engine.notifyWhenPlayersFinished { _ in .stopEngine }
        } catch {
            // Mapping is already saved; unavailable haptics must not interrupt it.
            feedbackEngine = nil
            feedbackControllerID = nil
        }
    }

    // MARK: - DeltaCore GameControllerInputMapping Generator
    
    func createDeltaInputMapping(for system: TVSystem) -> GameControllerInputMapping {
        var deltaMapping = GameControllerInputMapping(gameControllerInputType: .mfi)
        let systemMap = self.mappings[system] ?? self.defaultMapping(for: system)
        
        for (actionId, gamepadBtn) in systemMap {
            let mfiInput: AnyInput
            if let typedInput = MFiGameController.Input(rawValue: gamepadBtn.rawValue) {
                mfiInput = AnyInput(typedInput)
            } else {
                mfiInput = AnyInput(stringValue: gamepadBtn.rawValue, intValue: nil, type: .controller(.mfi))
            }
            
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
        } else {
            for (direction, physical) in [("up", MFiGameController.Input.leftThumbstickUp),
                                          ("down", .leftThumbstickDown), ("left", .leftThumbstickLeft), ("right", .leftThumbstickRight)] {
                if let input = self.consoleInput(for: direction, system: system) {
                    deltaMapping.set(input, forControllerInput: physical)
                }
            }
        }
        
        return deltaMapping
    }
    
    private func consoleInput(for actionId: String, system: TVSystem) -> Input? {
        system.core.gameInputType.init(stringValue: actionId)
    }
}
