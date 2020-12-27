//
//  File.swift
//  Harmony
//
//  Created by Riley Testut on 12/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public struct File: Hashable
{
    public var identifier: String
    public var fileURL: URL
    
    public init(identifier: String, fileURL: URL)
    {
        self.identifier = identifier
        self.fileURL = fileURL
    }
}
