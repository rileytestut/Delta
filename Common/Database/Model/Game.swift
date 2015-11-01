//
//  Game.swift
//  Delta
//
//  Created by Riley Testut on 10/3/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore
import SNESDeltaCore

@objc(Game)
class Game: NSManagedObject, GameType
{
    var fileURL: NSURL {
        let fileURL = DatabaseManager.gamesDirectoryURL.URLByAppendingPathComponent(self.filename)
        return fileURL
    }
}

extension Game
{
    class func supportedTypeIdentifiers() -> Set<String>
    {
        return [kUTTypeSNESGame as String]
    }
}
