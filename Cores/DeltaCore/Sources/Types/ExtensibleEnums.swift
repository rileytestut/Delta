//
//  ExtensibleEnum.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/9/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public protocol ExtensibleEnum: Hashable, Codable, RawRepresentable where RawValue == String {}

public extension ExtensibleEnum
{
    init(_ rawValue: String)
    {
        self.init(rawValue: rawValue)!
    }
    
    init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)!
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// Conform types to ExtensibleEnum to receive automatic Codable conformance + implementation.
extension GameType: ExtensibleEnum {}
extension CheatType: ExtensibleEnum {}
extension GameControllerInputType: ExtensibleEnum {}
