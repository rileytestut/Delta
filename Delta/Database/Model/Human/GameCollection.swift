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
        let gameType = GameType.gameType(forFileExtension: pathExtension ?? "")
        let identifier = gameType.rawValue
        
        let index: Int16
        
        switch gameType
        {
        case GameType.snes: index = 1990
        case GameType.gba: index = 2001
        case GameType.nds: index = 2004
        default: index = Int16(INT16_MAX)
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
