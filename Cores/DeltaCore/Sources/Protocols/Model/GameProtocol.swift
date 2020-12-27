//
//  GameProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import Foundation

public protocol GameProtocol
{
    var fileURL: URL { get }
    var gameSaveURL: URL { get }
    
    var type: GameType { get }
}

public extension GameProtocol
{
    var gameSaveURL: URL {
        let fileExtension = Delta.core(for: self.type)?.gameSaveFileExtension ?? "sav"
        
        let gameURL = self.fileURL.deletingPathExtension()
        let gameSaveURL = gameURL.appendingPathExtension(fileExtension)
        return gameSaveURL
    }
}
