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
        case kUTTypeSNESGame as String as String: return NSLocalizedString("Super Nintendo Entertainment System", comment: "")
        case kUTTypeGBAGame  as String as String: return NSLocalizedString("Game Boy Advance", comment: "")
        case kUTTypeDeltaGame as String as String: return NSLocalizedString("Unsupported Games", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
    
    var shortName: String {
        
        switch self.identifier
        {
        case kUTTypeSNESGame as String as String: return NSLocalizedString("SNES", comment: "")
        case kUTTypeGBAGame  as String as String: return NSLocalizedString("GBA", comment: "")
        case kUTTypeDeltaGame as String as String: return NSLocalizedString("Unsupported", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
    
    class func gameSystemCollectionForPathExtension(pathExtension: String?, inManagedObjectContext managedObjectContext: NSManagedObjectContext) -> GameCollection
    {
        let identifier: String
        let index: Int16
        
        switch pathExtension ?? ""
        {
        case "smc": fallthrough
        case "sfc": fallthrough
        case "fig":
            identifier = kUTTypeSNESGame as String
            index = 1990
            
        case "gba":
            identifier = kUTTypeGBAGame as String
            index = 2001
            
        default:
            identifier = kUTTypeDeltaGame as String
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
