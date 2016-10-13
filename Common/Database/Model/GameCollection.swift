//
//  GameCollection.swift
//  Delta
//
//  Created by Riley Testut on 11/1/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import CoreData

import DeltaCore
import SNESDeltaCore
import GBADeltaCore

@objc(GameCollection)
public class GameCollection: _GameCollection 
{
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
        
        let predicate = NSPredicate(format: "%K == %@", #keyPath(GameCollection.identifier), identifier)
        
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
