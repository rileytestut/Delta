//
//  SettingsUserInfoKey.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/13/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public extension SettingsUserInfoKey
{
    public static let name: SettingsUserInfoKey = "name"
    public static let value: SettingsUserInfoKey = "value"
}

public struct SettingsUserInfoKey: RawRepresentable, Hashable, ExpressibleByStringLiteral
{
    public let rawValue: String
    
    public init(rawValue: String)
    {
        self.rawValue = rawValue
    }

    public init(stringLiteral rawValue: String)
    {
        self.rawValue = rawValue
    }
}
