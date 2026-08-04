//
//  Input+Display.swift
//  Delta
//
//  Created by Riley Testut on 8/15/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore
import GBADeltaCore
import N64DeltaCore
import GPGXDeltaCore

extension Input
{
    // With the default GameControllerInputMapping files, multiple controller inputs may map to the same game input.
    // This is because each controller input maps to a unique standard input, but then multiple standard inputs may map to same game input.
    // To ensure we only show the most "important" controller input for a game input, we define general "display priorities" for each input.
    //
    // For example, MFiGameController.down and MFiGameController.leftThumbstickDown both map to a "down" game input.
    // However, .down has a higher priority than .leftThumbstickDown, so we show .down instead of .leftThumbstickDown.
    var displayPriority: Int {
        switch self.type
        {
        case .game: break
        case .controller(.standard): break
        case .controller(.mfi):
            let input = MFiGameController.Input(input: self)!
            switch input
            {
            case .leftThumbstickUp: return 750
            case .leftThumbstickDown: return 750
            case .leftThumbstickLeft: return 750
            case .leftThumbstickRight: return 750
            case .leftShoulder: return 750
            case .leftTrigger: return 500
            case .rightShoulder: return 750
            case .rightTrigger: return 500
            default: break
            }
        
        case .controller(.keyboard):
            let input = KeyboardGameController.Input(input: self)!
            
            if input == .escape
            {
                // The iPad Smart Keyboard doesn't have an escape key, so return lower priority
                // to ensure it only appears if there is no other key mapped to the same input.
                return 100
            }
            
            // We prefer to display keys with special characters (e.g. arrow keys, shift) over regular keys.
            // If the input's localizedName == it's string value, we can assume it's a normal key, and return a lower priority.
            // Otherwise, it has a special display character, and so we return a higher priority.
            if input.localizedName == input.stringValue.uppercased()
            {
                return 500
            }
            else
            {
                return 1000
            }
            
        default: break
        }
        
        return 1000
    }
    
    var localizedName: String {
        switch self.type
        {
        case .game: break
        case .controller(.standard):
            let input = StandardGameControllerInput(input: self)!
            switch input
            {
            case .menu: return NSLocalizedString("Menu", comment: "")
            case .up: return NSLocalizedString("Up", comment: "")
            case .down: return NSLocalizedString("Down", comment: "")
            case .left: return NSLocalizedString("Left", comment: "")
            case .right: return NSLocalizedString("Right", comment: "")
            case .leftThumbstickUp: return NSLocalizedString("L🕹↑", comment: "")
            case .leftThumbstickDown: return NSLocalizedString("L🕹↓", comment: "")
            case .leftThumbstickLeft: return NSLocalizedString("L🕹←", comment: "")
            case .leftThumbstickRight: return NSLocalizedString("L🕹→", comment: "")
            case .leftThumbstickButton: return NSLocalizedString("L3", comment: "")
            case .rightThumbstickUp: return NSLocalizedString("R🕹↑", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("R🕹↓", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("R🕹←", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("R🕹→", comment: "")
            case .rightThumbstickButton: return NSLocalizedString("R3", comment: "")
            case .a: return NSLocalizedString("A", comment: "")
            case .b: return NSLocalizedString("B", comment: "")
            case .x: return NSLocalizedString("X", comment: "")
            case .y: return NSLocalizedString("Y", comment: "")
            case .start: return NSLocalizedString("Start", comment: "Start button")
            case .select: return NSLocalizedString("Select", comment: "Select button")
            case .l1: return NSLocalizedString("L1", comment: "")
            case .l2: return NSLocalizedString("L2", comment: "")
            case .l3: return NSLocalizedString("L3", comment: "")
            case .r1: return NSLocalizedString("R1", comment: "")
            case .r2: return NSLocalizedString("R2", comment: "")
            case .r3: return NSLocalizedString("R3", comment: "")
            }
            
        case .controller(.mfi):
            let input = MFiGameController.Input(input: self)!
            switch input
            {
            case .menu: return NSLocalizedString("Menu", comment: "")
            case .up: return NSLocalizedString("Up", comment: "")
            case .down: return NSLocalizedString("Down", comment: "")
            case .left: return NSLocalizedString("Left", comment: "")
            case .right: return NSLocalizedString("Right", comment: "")
            case .leftThumbstickUp: return NSLocalizedString("L🕹↑", comment: "")
            case .leftThumbstickDown: return NSLocalizedString("L🕹↓", comment: "")
            case .leftThumbstickLeft: return NSLocalizedString("L🕹←", comment: "")
            case .leftThumbstickRight: return NSLocalizedString("L🕹→", comment: "")
            case .leftThumbstickButton: return NSLocalizedString("L3", comment: "")
            case .rightThumbstickUp: return NSLocalizedString("R🕹↑", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("R🕹↓", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("R🕹←", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("R🕹→", comment: "")
            case .rightThumbstickButton: return NSLocalizedString("R3", comment: "")
            case .a: return NSLocalizedString("A", comment: "")
            case .b: return NSLocalizedString("B", comment: "")
            case .x: return NSLocalizedString("X", comment: "")
            case .y: return NSLocalizedString("Y", comment: "")
            case .leftShoulder: return NSLocalizedString("L1", comment: "")
            case .leftTrigger: return NSLocalizedString("L2", comment: "")
            case .rightShoulder: return NSLocalizedString("R1", comment: "")
            case .rightTrigger: return NSLocalizedString("R2", comment: "")
            case .start: return NSLocalizedString("Start", comment: "")
            case .select: return NSLocalizedString("Select", comment: "")
            }
            
        case .controller(.keyboard):
            let input = KeyboardGameController.Input(input: self)!
            switch input
            {
            case .up: return NSLocalizedString("↑", comment: "")
            case .down: return NSLocalizedString("↓", comment: "")
            case .left: return NSLocalizedString("←", comment: "")
            case .right: return NSLocalizedString("→", comment: "")
            case .escape: return NSLocalizedString("⎋", comment: "")
            case .shift: return NSLocalizedString("⇧", comment: "")
            case .command: return NSLocalizedString("⌘", comment: "")
            case .option: return NSLocalizedString("⌥", comment: "")
            case .control: return NSLocalizedString("Ctrl", comment: "")
            case .capsLock: return NSLocalizedString("⇪", comment: "")
            case .space: return NSLocalizedString("Space", comment: "")
            case .return: return NSLocalizedString("↩\u{FE0E}", comment: "")
            case .tab: return NSLocalizedString("⇥", comment: "")
            default: return input.stringValue.uppercased()
            }
            
        default: break
        }
        
        return ""
    }
    
    // Editor-facing names (e.g. "A Button" instead of "A"); localizedName is unchanged for backwards compatibility.
    var localizedDisplayName: String {
        switch self.type
        {
        case .game:
            // Each core defines its own inputs, so reference multiple systems to cover every game input.
            switch self.stringValue
            {
            case GBAGameInput.up.stringValue: return NSLocalizedString("Up", comment: "")
            case GBAGameInput.down.stringValue: return NSLocalizedString("Down", comment: "")
            case GBAGameInput.left.stringValue: return NSLocalizedString("Left", comment: "")
            case GBAGameInput.right.stringValue: return NSLocalizedString("Right", comment: "")
            case GBAGameInput.a.stringValue: return NSLocalizedString("A", comment: "")
            case GBAGameInput.b.stringValue: return NSLocalizedString("B", comment: "")
            case GPGXGameInput.c.stringValue: return NSLocalizedString("C", comment: "")
            case GPGXGameInput.x.stringValue: return NSLocalizedString("X", comment: "")
            case GPGXGameInput.y.stringValue: return NSLocalizedString("Y", comment: "")
            case GPGXGameInput.z.stringValue: return NSLocalizedString("Z", comment: "")
            case GBAGameInput.l.stringValue: return NSLocalizedString("L", comment: "")
            case GBAGameInput.r.stringValue: return NSLocalizedString("R", comment: "")
            case GBAGameInput.start.stringValue: return NSLocalizedString("Start", comment: "")
            case GBAGameInput.select.stringValue: return NSLocalizedString("Select", comment: "")
            case GPGXGameInput.mode.stringValue: return NSLocalizedString("Mode", comment: "")
            case N64GameInput.analogStickUp.stringValue: return NSLocalizedString("Analog Stick Up", comment: "")
            case N64GameInput.analogStickDown.stringValue: return NSLocalizedString("Analog Stick Down", comment: "")
            case N64GameInput.analogStickLeft.stringValue: return NSLocalizedString("Analog Stick Left", comment: "")
            case N64GameInput.analogStickRight.stringValue: return NSLocalizedString("Analog Stick Right", comment: "")
            case N64GameInput.cUp.stringValue: return NSLocalizedString("C-Up", comment: "")
            case N64GameInput.cDown.stringValue: return NSLocalizedString("C-Down", comment: "")
            case N64GameInput.cLeft.stringValue: return NSLocalizedString("C-Left", comment: "")
            case N64GameInput.cRight.stringValue: return NSLocalizedString("C-Right", comment: "")
            default: return self.stringValue.capitalized
            }
            
        case .controller(.standard):
            let input = StandardGameControllerInput(input: self)!
            switch input
            {
            case .menu: return NSLocalizedString("Menu", comment: "")
            case .up: return NSLocalizedString("Up", comment: "")
            case .down: return NSLocalizedString("Down", comment: "")
            case .left: return NSLocalizedString("Left", comment: "")
            case .right: return NSLocalizedString("Right", comment: "")
            case .leftThumbstickUp: return NSLocalizedString("Up", comment: "")
            case .leftThumbstickDown: return NSLocalizedString("Down", comment: "")
            case .leftThumbstickLeft: return NSLocalizedString("Left", comment: "")
            case .leftThumbstickRight: return NSLocalizedString("Right", comment: "")
            case .rightThumbstickUp: return NSLocalizedString("Up", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("Down", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("Left", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("Right", comment: "")
            case .a: return NSLocalizedString("A Button", comment: "")
            case .b: return NSLocalizedString("B Button", comment: "")
            case .x: return NSLocalizedString("X Button", comment: "")
            case .y: return NSLocalizedString("Y Button", comment: "")
            case .start: return NSLocalizedString("Start", comment: "")
            case .select: return NSLocalizedString("Select", comment: "")
            case .l1: return NSLocalizedString("L1 Button", comment: "")
            case .l2: return NSLocalizedString("L2 Button", comment: "")
            case .l3: return NSLocalizedString("L3 Button", comment: "")
            case .r1: return NSLocalizedString("R1 Button", comment: "")
            case .r2: return NSLocalizedString("R2 Button", comment: "")
            case .r3: return NSLocalizedString("R3 Button", comment: "")
            }
            
        case .controller(.mfi):
            let input = MFiGameController.Input(input: self)!
            switch input
            {
            case .menu: return NSLocalizedString("Menu", comment: "")
            case .up: return NSLocalizedString("Up", comment: "")
            case .down: return NSLocalizedString("Down", comment: "")
            case .left: return NSLocalizedString("Left", comment: "")
            case .right: return NSLocalizedString("Right", comment: "")
            case .leftThumbstickUp: return NSLocalizedString("Up", comment: "")
            case .leftThumbstickDown: return NSLocalizedString("Down", comment: "")
            case .leftThumbstickLeft: return NSLocalizedString("Left", comment: "")
            case .leftThumbstickRight: return NSLocalizedString("Right", comment: "")
            case .rightThumbstickUp: return NSLocalizedString("Up", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("Down", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("Left", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("Right", comment: "")
            case .a: return NSLocalizedString("A Button", comment: "")
            case .b: return NSLocalizedString("B Button", comment: "")
            case .x: return NSLocalizedString("X Button", comment: "")
            case .y: return NSLocalizedString("Y Button", comment: "")
            case .leftShoulder: return NSLocalizedString("L1 Button", comment: "")
            case .leftTrigger: return NSLocalizedString("L2 Button", comment: "")
            case .rightShoulder: return NSLocalizedString("R1 Button", comment: "")
            case .rightTrigger: return NSLocalizedString("R2 Button", comment: "")
            case .start: return NSLocalizedString("Start", comment: "")
            case .select: return NSLocalizedString("Select", comment: "")
            }
            
        case .controller(.keyboard):
            let input = KeyboardGameController.Input(input: self)!
            switch input
            {
            case .up: return NSLocalizedString("Up Arrow", comment: "")
            case .down: return NSLocalizedString("Down Arrow", comment: "")
            case .left: return NSLocalizedString("Left Arrow", comment: "")
            case .right: return NSLocalizedString("Right Arrow", comment: "")
            case .escape: return NSLocalizedString("Escape", comment: "")
            case .shift: return NSLocalizedString("Shift", comment: "")
            case .command: return NSLocalizedString("Command", comment: "")
            case .option: return NSLocalizedString("Option", comment: "")
            case .control: return NSLocalizedString("Control", comment: "")
            case .capsLock: return NSLocalizedString("Caps Lock", comment: "")
            case .space: return NSLocalizedString("Space", comment: "")
            case .return: return NSLocalizedString("Return", comment: "")
            case .tab: return NSLocalizedString("Tab", comment: "")
            default: return input.stringValue.uppercased()
            }
            
        case .controller(.action):
            let input = ActionInput(input: self)!
            switch input
            {
            case .quickSave: return NSLocalizedString("Quick Save", comment: "")
            case .quickLoad: return NSLocalizedString("Quick Load", comment: "")
            case .fastForward: return NSLocalizedString("Fast Forward", comment: "")
            case .toggleFastForward: return NSLocalizedString("Toggle Fast Forward", comment: "")
            case .reverseScreens: return NSLocalizedString("Reverse Screens", comment: "")
            case .screenshot: return NSLocalizedString("Screenshot", comment: "")
            }
            
        default: break
        }
        
        return ""
    }
    
    var sfSymbolName: String {
        switch self.type
        {
        case .game:
            // Each core defines its own inputs, so reference multiple systems to cover every game input.
            switch self.stringValue
            {
            case GBAGameInput.up.stringValue: return "dpad.up.filled"
            case GBAGameInput.down.stringValue: return "dpad.down.filled"
            case GBAGameInput.left.stringValue: return "dpad.left.filled"
            case GBAGameInput.right.stringValue: return "dpad.right.filled"
            case GBAGameInput.a.stringValue: return "a.circle"
            case GBAGameInput.b.stringValue: return "b.circle"
            case GPGXGameInput.c.stringValue: return "c.circle"
            case GPGXGameInput.x.stringValue: return "x.circle"
            case GPGXGameInput.y.stringValue: return "y.circle"
            case GPGXGameInput.z.stringValue: return "z.circle"
            case GBAGameInput.l.stringValue: return "l.button.roundedbottom.horizontal"
            case GBAGameInput.r.stringValue: return "r.button.roundedbottom.horizontal"
            case GBAGameInput.start.stringValue: return "play.circle"
            case GBAGameInput.select.stringValue: return "line.3.horizontal.circle"
            case GPGXGameInput.mode.stringValue: return "ellipsis.circle"
            case N64GameInput.analogStickUp.stringValue: return "l.joystick.tilt.up"
            case N64GameInput.analogStickDown.stringValue: return "l.joystick.tilt.down"
            case N64GameInput.analogStickLeft.stringValue: return "l.joystick.tilt.left"
            case N64GameInput.analogStickRight.stringValue: return "l.joystick.tilt.right"
            case N64GameInput.cUp.stringValue: return "circle.grid.cross.up.filled"
            case N64GameInput.cDown.stringValue: return "circle.grid.cross.down.filled"
            case N64GameInput.cLeft.stringValue: return "circle.grid.cross.left.filled"
            case N64GameInput.cRight.stringValue: return "circle.grid.cross.right.filled"
            default: return "questionmark.circle"
            }
            
        case .controller(.standard):
            let input = StandardGameControllerInput(input: self)!
            switch input
            {
            case .menu: return "house.circle"
            case .up: return "dpad.up.filled"
            case .down: return "dpad.down.filled"
            case .left: return "dpad.left.filled"
            case .right: return "dpad.right.filled"
            case .leftThumbstickUp: return "l.joystick.tilt.up"
            case .leftThumbstickDown: return "l.joystick.tilt.down"
            case .leftThumbstickLeft: return "l.joystick.tilt.left"
            case .leftThumbstickRight: return "l.joystick.tilt.right"
            case .rightThumbstickUp: return "r.joystick.tilt.up"
            case .rightThumbstickDown: return "r.joystick.tilt.down"
            case .rightThumbstickLeft: return "r.joystick.tilt.left"
            case .rightThumbstickRight: return "r.joystick.tilt.right"
            case .a: return "a.circle"
            case .b: return "b.circle"
            case .x: return "x.circle"
            case .y: return "y.circle"
            case .start: return "play.circle"
            case .select: return "line.3.horizontal.circle"
            case .l1: return "l1.button.roundedbottom.horizontal"
            case .l2: return "l2.button.roundedtop.horizontal"
            case .l3: return "l.joystick.press.down"
            case .r1: return "r1.button.roundedbottom.horizontal"
            case .r2: return "r2.button.roundedtop.horizontal"
            case .r3: return "r.joystick.press.down"
            }
            
        case .controller(.mfi):
            let input = MFiGameController.Input(input: self)!
            switch input
            {
            case .menu: return "house.circle"
            case .up: return "dpad.up.filled"
            case .down: return "dpad.down.filled"
            case .left: return "dpad.left.filled"
            case .right: return "dpad.right.filled"
            case .leftThumbstickUp: return "l.joystick.tilt.up"
            case .leftThumbstickDown: return "l.joystick.tilt.down"
            case .leftThumbstickLeft: return "l.joystick.tilt.left"
            case .leftThumbstickRight: return "l.joystick.tilt.right"
            case .rightThumbstickUp: return "r.joystick.tilt.up"
            case .rightThumbstickDown: return "r.joystick.tilt.down"
            case .rightThumbstickLeft: return "r.joystick.tilt.left"
            case .rightThumbstickRight: return "r.joystick.tilt.right"
            case .a: return "a.circle"
            case .b: return "b.circle"
            case .x: return "x.circle"
            case .y: return "y.circle"
            case .leftShoulder: return "l1.button.roundedbottom.horizontal"
            case .leftTrigger: return "l2.button.roundedtop.horizontal"
            case .rightShoulder: return "r1.button.roundedbottom.horizontal"
            case .rightTrigger: return "r2.button.roundedtop.horizontal"
            case .start: return "plus.circle"
            case .select: return "minus.circle"
            }
            
        case .controller(.keyboard):
            let input = KeyboardGameController.Input(input: self)!
            switch input
            {
            case .up: return "arrowkeys.up.filled"
            case .down: return "arrowkeys.down.filled"
            case .left: return "arrowkeys.left.filled"
            case .right: return "arrowkeys.right.filled"
            case .escape: return "escape"
            case .shift: return "shift"
            case .command: return "command"
            case .option: return "option"
            case .control: return "control"
            case .capsLock: return "capslock"
            case .return: return "return"
            case .space : return "space"
            case .tab: return "arrow.right.to.line"
            default:
                let stringValue = input.stringValue.lowercased()
                
                // There are built-in SF symbols for letters and numbers.
                // Identify letters and numbers, and use their built-in SF symbols.
                if stringValue.count == 1, let character = stringValue.first, character.isASCII, character.isLetter || character.isNumber
                {
                    return "\(stringValue).square"
                }
                
                // Otherwise default to generic keyboard symbol.
                return "keyboard"
            }
            
        case .controller(.action):
            let input = ActionInput(input: self)!
            switch input
            {
            case .quickSave: return "square.and.arrow.down"
            case .quickLoad: return "square.and.arrow.up"
            case .fastForward: return "forward"
            case .toggleFastForward: return "forward"
            case .reverseScreens: return "rectangle.2.swap"
            case .screenshot: return "camera"
            }
            
        default: return "questionmark.circle"
        }
    }
}
