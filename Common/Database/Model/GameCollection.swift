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
    
    var name: String
    {
        let gameType = GameType(rawValue: self.identifier)
        return gameType.localizedName
    }
    
    var shortName: String
    {
        let gameType = GameType(rawValue: self.identifier)
        return gameType.localizedShortName
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
        
        let predicate = NSPredicate(format: "%K == %@", GameCollection.Attributes.identifier.rawValue, identifier)
        
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
