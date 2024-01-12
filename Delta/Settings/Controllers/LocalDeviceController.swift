//
//  LocalDeviceController.swift
//  Delta
//
//  Created by Riley Testut on 1/12/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import DeltaCore

class LocalDeviceController: NSObject, GameController
{
    var name: String {
        if ProcessInfo.processInfo.isRunningOnVisionPro
        {
            return NSLocalizedString("Touch", comment: "")
        }
        else
        {
            return NSLocalizedString("Touch Screen", comment: "")
        }
    }
    
    var playerIndex: Int? {
        set { Settings.localControllerPlayerIndex = newValue }
        get { return Settings.localControllerPlayerIndex }
    }
    
    let inputType: GameControllerInputType = .standard
    
    var defaultInputMapping: GameControllerInputMappingProtocol?
}
