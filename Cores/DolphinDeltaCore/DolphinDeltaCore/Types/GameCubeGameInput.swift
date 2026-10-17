//
//  GameCubeGameInput.swift
//  DolphinDeltaCore
//
//  Created by Riley Testut on 1/28/21.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation
import DeltaCore


@objc public enum GameCubeGameInput: Int, Input
{
    // D-Pad
    case up = 0
    case down = 1
    case left = 2
    case right = 3
    
    // Main Control Stick
    case controlStickUp = 4
    case controlStickDown = 5
    case controlStickLeft = 6
    case controlStickRight = 7
    
    // C-Stick
    case cStickUp = 8
    case cStickDown = 9
    case cStickLeft = 10
    case cStickRight = 11
    
    // Face Buttons
    case a = 12
    case b = 13
    case x = 14
    case y = 15
    
    // Triggers & Bumpers
    case l = 16
    case r = 17
    case z = 18
    
    // System
    case start = 19
    
    public var type: InputType {
        return .game(GameType.gamecube)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .controlStickUp, .controlStickDown, .controlStickLeft, .controlStickRight,
             .cStickUp, .cStickDown, .cStickLeft, .cStickRight,
             .l, .r:
            return true
        default:
            return false
        }
    }
}
