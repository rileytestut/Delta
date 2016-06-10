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
import GBADeltaCore

extension Game
{
    enum Attributes: String
    {
        case artworkURL
        case filename
        case identifier
        case name
        case typeIdentifier
        
        case gameCollections
        case saveStates
        case previewSaveState
        case cheats
    }
}

@objc(Game)
class Game: NSManagedObject, GameType
{
    @NSManaged var artworkURL: NSURL?
    @NSManaged var filename: String
    @NSManaged var identifier: String
    @NSManaged var name: String
    @NSManaged var typeIdentifier: String
    
    @NSManaged var gameCollections: Set<GameCollection>
    @NSManaged var previewSaveState: SaveState?
    
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
