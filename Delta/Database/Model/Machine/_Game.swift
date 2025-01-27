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

    @NSManaged public var gameSettings: NSDictionary?

    @NSManaged public var identifier: String

    @NSManaged public var name: String

    @NSManaged public var playedDate: Date?

    @NSManaged public var type: GameType

    // MARK: - Relationships

    @NSManaged public var cheats: Set<Cheat>

    @NSManaged public var gameCollection: GameCollection?

    @NSManaged public var gameSave: GameSave?

    @NSManaged public var preferredExternalControllerLandscapeSkin: ControllerSkin?

    @NSManaged public var preferredExternalControllerPortraitSkin: ControllerSkin?

    @NSManaged public var preferredLandscapeSkin: ControllerSkin?

    @NSManaged public var preferredPortraitSkin: ControllerSkin?

    @NSManaged public var preferredSplitViewLandscapeSkin: ControllerSkin?

    @NSManaged public var preferredSplitViewPortraitSkin: ControllerSkin?

    @NSManaged public var previewSaveState: SaveState?

    @NSManaged public var primaryGames: Set<Game>

    @NSManaged public var saveStates: Set<SaveState>

    @NSManaged public var secondaryGame: Game?

}

