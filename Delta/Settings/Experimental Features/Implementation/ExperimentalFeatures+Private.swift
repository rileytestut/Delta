//
//  ExperimentalFeatures+Private.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

internal extension ExperimentalFeatures
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
            feature.key = key
        }
    }
}
