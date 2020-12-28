// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to ControllerSkin.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _ControllerSkin: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ControllerSkin> {
        return NSFetchRequest<ControllerSkin>(entityName: "ControllerSkin")
    }

    // MARK: - Properties

    @NSManaged public var filename: String

    @NSManaged public var gameType: GameType

    @NSManaged public var identifier: String

    @NSManaged public var isStandard: Bool

    @NSManaged public var name: String

    @NSManaged public var supportedConfigurations: ControllerSkinConfigurations

    // MARK: - Relationships

    @NSManaged public var preferredLandscapeSkinByGames: Set<Game>

    @NSManaged public var preferredPortraitSkinByGames: Set<Game>

}

