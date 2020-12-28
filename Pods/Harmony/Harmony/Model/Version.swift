//
//  Version.swift
//  Harmony
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public struct Version: Hashable
{
    public var identifier: String
    public var date: Date
    
    public init(identifier: String, date: Date)
    {
        self.identifier = identifier
        self.date = date
    }
}
