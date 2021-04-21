// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SaveState.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _SaveState: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SaveState> {
        return NSFetchRequest<SaveState>(entityName: "SaveState")
    }

    // MARK: - Properties

    @NSManaged public var coreIdentifier: String?

    @NSManaged public var creationDate: Date

    @NSManaged public var filename: String

    @NSManaged public var identifier: String

    @NSManaged public var modifiedDate: Date

    @NSManaged public var name: String?

    @NSManaged public var type: SaveStateType

    // MARK: - Relationships

    @NSManaged public var game: Game?

    @NSManaged public var previewGame: Game?

}

