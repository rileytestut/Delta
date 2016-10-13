// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to GameCollection.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _GameCollection: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GameCollection> {
        return NSFetchRequest<GameCollection>(entityName: "GameCollection")
    }

    // MARK: - Properties

    @NSManaged public var identifier: String

    @NSManaged public var index: Int16

    // MARK: - Relationships

    @NSManaged public var games: Set<Game>

}

