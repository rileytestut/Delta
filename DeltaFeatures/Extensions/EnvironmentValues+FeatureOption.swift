//
//  EnvironmentValues+FeatureOption.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/26/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

private struct FeatureOptionKey: EnvironmentKey
{
    static let defaultValue: any AnyOption = Option(wrappedValue: true)
}

public extension EnvironmentValues
{
    var featureOption: any AnyOption {
        get { self[FeatureOptionKey.self] }
        set { self[FeatureOptionKey.self] = newValue }
    }
}
