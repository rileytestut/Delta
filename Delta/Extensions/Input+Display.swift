//
//  Input+Display.swift
//  Delta
//
//  Created by Riley Testut on 8/15/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

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
            case .rightThumbstickUp: return NSLocalizedString("R🕹↑", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("R🕹↓", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("R🕹←", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("R🕹→", comment: "")
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
            case .rightThumbstickUp: return NSLocalizedString("R🕹↑", comment: "")
            case .rightThumbstickDown: return NSLocalizedString("R🕹↓", comment: "")
            case .rightThumbstickLeft: return NSLocalizedString("R🕹←", comment: "")
            case .rightThumbstickRight: return NSLocalizedString("R🕹→", comment: "")
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
}
