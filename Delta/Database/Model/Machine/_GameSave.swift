// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to GameSave.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _GameSave: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GameSave> {
        return NSFetchRequest<GameSave>(entityName: "GameSave")
    }

    // MARK: - Properties

    @NSManaged public var identifier: String

    @NSManaged public var modifiedDate: Date

    @NSManaged public var sha1: String?

    // MARK: - Relationships

    @NSManaged public var game: Game?

}

