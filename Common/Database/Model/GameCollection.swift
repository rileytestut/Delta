//
//  GameCollection.swift
//  Delta
//
//  Created by Riley Testut on 11/1/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import SNESDeltaCore

@objc(GameCollection)
class GameCollection: NSManagedObject
{
    class func gameSystemCollectionForPathExtension(pathExtension: String?, inManagedObjectContext managedObjectContext: NSManagedObjectContext) -> GameCollection?
    {
        guard let pathExtension = pathExtension else { return nil }
        
        let identifier: String
        let name: String
        let shortName: String
        
        switch pathExtension
        {
        case "smc": fallthrough
        case "sfc": fallthrough
        case "fig":
            identifier = kUTTypeSNESGame as String
            name = "Super Nintendo Entertainment System"
            shortName = "SNES"
            
            
            
        default: return nil
        }
        
        let predicate = NSPredicate(format: "%K == %@", GameCollectionAttributes.identifier.rawValue, identifier)
        
        var gameCollection = GameCollection.instancesWithPredicate(predicate, inManagedObjectContext: managedObjectContext, type: GameCollection.self).first
        if gameCollection == nil
        {
            gameCollection = GameCollection.insertIntoManagedObjectContext(managedObjectContext)
            gameCollection?.identifier = identifier
            gameCollection?.name = name
            gameCollection?.shortName = shortName
        }
        
        return gameCollection
    }
}
