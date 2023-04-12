//
//  FeatureContainer.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public protocol FeatureContainer
{
}

public extension FeatureContainer
{
    var allFeatures: [AnyFeature] {
        let features = Mirror(reflecting: self).children.compactMap { (child) -> (AnyFeature)? in
            let feature = child.value as? AnyFeature
            return feature
        }
        return features
    }
    
    func prepareFeatures()
    {
        // Assign keys to property names.
        for case (let key?, let feature as AnyFeature) in Mirror(reflecting: self).children
        {
            // Remove leading underscore.
            let sanitizedKey = key.dropFirst()
            feature.key = String(sanitizedKey)
        }
    }
}
