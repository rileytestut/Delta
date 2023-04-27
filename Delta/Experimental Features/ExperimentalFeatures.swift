//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import DeltaFeatures

struct ExperimentalFeatures: FeatureContainer
{
    static let shared = ExperimentalFeatures()
    
    @Feature(name: "Variable Fast Forward",
             description: "Change the preferred Fast Foward speed per-system. You can also change it by long-pressing the Fast Forward button from the Pause Menu.",
             options: VariableFastForwardOptions())
    var variableFastForward
    
    @Feature(name: "Toast Notifications",
             description: "Show toast notifications as a confirmation for various actions, such as saving your game or loading a save state.",
             options: ToastNotificationOptions())
    var toastNotifications
    
    private init()
    {
        self.prepareFeatures()
    }
}
