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
    
    @Feature(name: "Custom Box Art")
    var customBoxArt
    
    @Feature(name: "Random Dancing")
    var randomDancing
    
    @Feature(name: "Variable Fast Forward",
             description: "Change the maximum Fast Foward speed per-system. You can also change it by long-pressing the Fast Forward button from the Pause Menu.",
             options: VariableFastForwardOptions())
    var variableFastForward
    
    @Feature(name: "Custom Tint Color", options: CustomTintColorOptions())
    var customTintColor
    
    private init()
    {
        self.prepareFeatures()
    }
}
