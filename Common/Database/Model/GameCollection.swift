//
//  GameCollection.swift
//  Delta
//
//  Created by Riley Testut on 11/1/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore
import SNESDeltaCore
import GBADeltaCore

extension GameCollection
{
    enum Attributes: String
    {
        case identifier
        case index
        
        case games
    }
}

@objc(GameCollection)
class GameCollection: NSManagedObject
{
    @NSManaged private(set) var identifier: String
    @NSManaged private(set) var index: Int16
    
    @NSManaged var games: Set<Game>
    
    var name: String {
        
        switch self.identifier
        {
        case GameType.snes.rawValue: return NSLocalizedString("Super Nintendo Entertainment System", comment: "")
        case GameType.gba.rawValue: return NSLocalizedString("Game Boy Advance", comment: "")
        case GameType.delta.rawValue: return NSLocalizedString("Unsupported Games", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
    
    var shortName: String {
        
        switch self.identifier
        {
        case GameType.snes.rawValue as String as String: return NSLocalizedString("SNES", comment: "")
        case GameType.gba.rawValue  as String as String: return NSLocalizedString("GBA", comment: "")
        case GameType.delta.rawValue as String as String: return NSLocalizedString("Unsupported", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
    
    class func gameSystemCollectionForPathExtension(_ pathExtension: String?, inManagedObjectContext managedObjectContext: NSManagedObjectContext) -> GameCollection
    {
        let identifier: String
        let index: Int16
        
        switch pathExtension ?? ""
        {
        case "smc": fallthrough
        case "sfc": fallthrough
        case "fig":
            identifier = GameType.snes.rawValue
            index = 1990
            
        case "gba":
            identifier = GameType.gba.rawValue
            index = 2001
            
        default:
            identifier = GameType.delta.rawValue
            index = Int16(INT16_MAX)
        }
        
        let predicate = Predicate(format: "%K == %@", GameCollection.Attributes.identifier.rawValue, identifier)
        
        var gameCollection = GameCollection.instancesWithPredicate(predicate, inManagedObjectContext: managedObjectContext, type: GameCollection.self).first
        if gameCollection == nil
        {
            gameCollection = GameCollection.insertIntoManagedObjectContext(managedObjectContext)
            gameCollection?.identifier = identifier
            gameCollection?.index = index
        }
        
        return gameCollection!
    }
}
