// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to GameControllerInputMapping.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _GameControllerInputMapping: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GameControllerInputMapping> {
        return NSFetchRequest<GameControllerInputMapping>(entityName: "GameControllerInputMapping")
    }

    // MARK: - Properties

    @NSManaged public var deltaCoreInputMapping: Any

    @NSManaged public var gameControllerInputType: GameControllerInputType

    @NSManaged public var gameType: GameType

    @NSManaged public var identifier: String

    @NSManaged public var playerIndex: Int16

    // MARK: - Relationships

}

