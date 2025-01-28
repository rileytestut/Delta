//
//  ActionInput.swift
//  Delta
//
//  Created by Riley Testut on 8/28/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

public extension GameControllerInputType
{
    static let action = GameControllerInputType("com.rileytestut.Delta.input.action")
}

enum ActionInput: String
{
    case quickSave
    case quickLoad
    case fastForward
    case toggleFastForward
    case reverseScreens
    case screenshot
}

extension ActionInput: Input
{
    var type: InputType {
        return .controller(.action)
    }
}
