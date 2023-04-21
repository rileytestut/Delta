//
//  ExperimentalFeatures.swift
//  DeltaPreviews
//
//  Created by Riley Testut on 4/17/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import DeltaFeatures

import SwiftUI

struct ExperimentalFeatures: FeatureContainer
{
    static let shared = ExperimentalFeatures()
    
    @Feature(name: "Random Dancing")
    var randomDancing
    
    @Feature(name: "Custom Tint Color",
             description: "Change the accent color used throughout the app.",
             options: CustomTintColorOptions())
    var customTintColor
    
    @Feature(name: "Variable Fast Forward",
             description: "Change the preferred Fast Foward speed per-system. You can also change it by long-pressing the Fast Forward button from the Pause Menu.",
             options: VariableFastForwardOptions())
    var variableFastForward
    
    private init()
    {
        self.prepareFeatures()
    }
}

struct ExperimentalFeatures_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentalFeaturesView()
        }
    }
}
