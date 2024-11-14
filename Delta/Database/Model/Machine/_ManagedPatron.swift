// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to ManagedPatron.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _ManagedPatron: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ManagedPatron> {
        return NSFetchRequest<ManagedPatron>(entityName: "ManagedPatron")
    }

    // MARK: - Properties

    @NSManaged public var identifier: String

    @NSManaged public var isPatreonPatron: Bool

    @NSManaged public var name: String?

    // MARK: - Relationships

}

