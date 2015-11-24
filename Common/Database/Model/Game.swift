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

public let kUTTypeGBAGame: CFStringRef = "com.rileytestut.delta.game.gba"

@objc(Game)
class Game: NSManagedObject, GameType
{
    var fileURL: NSURL {
        let fileURL = DatabaseManager.gamesDirectoryURL.URLByAppendingPathComponent(self.filename)
        return fileURL
    }
    
    var preferredFileExtension: String {
        switch self.typeIdentifier
        {
        case kUTTypeSNESGame as String as String: return "smc"
        case kUTTypeGBAGame  as String as String: return "gba"
        case kUTTypeDeltaGame as String as String: fallthrough
        default: return "delta"
        }
    }
}

extension Game
{
    class func supportedTypeIdentifiers() -> Set<String>
    {
        return [kUTTypeSNESGame as String, kUTTypeGBAGame as String]
    }
}
