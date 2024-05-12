//
//  SettingsTypes.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public struct SettingsName: RawRepresentable, Hashable, ExpressibleByStringLiteral
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
