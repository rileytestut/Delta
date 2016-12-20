// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Game.swift instead.

import Foundation
import CoreData

import DeltaCore

public class _Game: NSManagedObject 
{   
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    // MARK: - Properties

    @NSManaged public var artworkURL: URL?

    @NSManaged public var filename: String

    @NSManaged public var identifier: String

    @NSManaged public var name: String

    @NSManaged public var type: GameType

    // MARK: - Relationships

    @NSManaged public var cheats: Set<Cheat>

    @NSManaged public var gameCollections: Set<GameCollection>

    @NSManaged public var previewSaveState: SaveState?

    @NSManaged public var saveStates: Set<SaveState>

}

