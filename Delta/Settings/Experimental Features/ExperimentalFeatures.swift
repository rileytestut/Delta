//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

struct ExperimentalFeatures
{
    static let shared = ExperimentalFeatures()
    
    @Feature(name: "Custom Box Art")
    var customBoxArt
    
    @Feature(name: "Variable Fast Forward")
    var variableFastForward
    
    @Feature(name: "Custom Tint Color", options: VariableFastForwardOptions())
    var customTintColor
    
    private init()
    {
        // Assign keys to property names.
        for case (let key?, let feature as AnyFeature) in Mirror(reflecting: self).children
        {
            feature.key = key
        }
    }
}
