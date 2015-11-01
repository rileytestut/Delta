//
//  GameCollection+CoreDataProperties.swift
//  Delta
//
//  Created by Riley Testut on 11/1/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

enum GameCollectionAttributes: String
{
    case name
    case identifier
    case shortName
    
    case games
}

extension GameCollection {

    @NSManaged var name: String
    @NSManaged var identifier: String
    @NSManaged var shortName: String?
    
    @NSManaged var games: Set<Game>
}
