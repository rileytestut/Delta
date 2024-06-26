// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to PatreonAccount.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _PatreonAccount: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PatreonAccount> {
        return NSFetchRequest<PatreonAccount>(entityName: "PatreonAccount")
    }

    // MARK: - Properties

    @NSManaged public var firstName: String?

    @NSManaged public var hasBetaAccess: Bool

    @NSManaged public var hasPastBetaAccess: Bool

    @NSManaged public var identifier: String

    @NSManaged public var isPatron: Bool

    @NSManaged public var name: String

    // MARK: - Relationships

}

