// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Cheat.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _Cheat: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Cheat> {
        return NSFetchRequest<Cheat>(entityName: "Cheat")
    }

    // MARK: - Properties

    @NSManaged public var code: String

    @NSManaged public var creationDate: Date

    @NSManaged public var identifier: String

    @NSManaged public var isEnabled: Bool

    @NSManaged public var modifiedDate: Date

    @NSManaged public var name: String

    @NSManaged public var type: CheatType

    // MARK: - Relationships

    @NSManaged public var game: Game?

}

