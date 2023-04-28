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
    
    @Feature(name: "Show Status Bar",
             description: "Enable to show the Status Bar during gameplay.")
    var showStatusBar
    
    private init()
    {
        self.prepareFeatures()
    }
}
