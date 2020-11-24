//
//  SaveState.swift
//  Delta
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import Harmony

import struct DSDeltaCore.DS

@objc public enum SaveStateType: Int16
{
    case auto
    case quick
    case general
    case locked
}

@objc(SaveState)
public class SaveState: _SaveState, SaveStateProtocol
{
    public static let localizedDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        return dateFormatter
    }()
    
    public var fileURL: URL {
        let fileURL = DatabaseManager.saveStatesDirectoryURL(for: self.game!).appendingPathComponent(self.filename)
        return fileURL
    }
    
    public var imageFileURL: URL {
        let imageFilename = (self.filename as NSString).deletingPathExtension + ".png"
        let imageFileURL = DatabaseManager.saveStatesDirectoryURL(for: self.game!).appendingPathComponent(imageFilename)
        return imageFileURL
    }
    
    public var gameType: GameType {
        return self.game!.type
    }
    
    public var localizedName: String {
        let localizedName = self.name ?? SaveState.localizedDateFormatter.string(from: self.modifiedDate)
        return localizedName
    }
    
    @NSManaged private var primitiveFilename: String
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: Date
    @NSManaged private var primitiveModifiedDate: Date
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = UUID().uuidString
        let date = Date()
        
        self.primitiveIdentifier = identifier
        self.primitiveFilename = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
    
    public override func prepareForDeletion()
    {
        super.prepareForDeletion()
        
        // In rare cases, game may actually be nil if game is corrupted, so we ensure it is non-nil first
        guard self.game != nil else { return }
        
        guard let managedObjectContext = self.managedObjectContext else { return }
        
        // If a save state with the same identifier is also currently being inserted, Core Data is more than likely resolving a conflict by deleting the previous instance
        // In this case, we make sure we DON'T delete the save state file + misc other Core Data relationships, or else we'll just lose all that data
        guard !managedObjectContext.insertedObjects.contains(where: { ($0 as? SaveState)?.identifier == self.identifier }) else { return }
        
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        
        do
        {
            try FileManager.default.removeItem(at: self.fileURL)
            try FileManager.default.removeItem(at: self.imageFileURL)
        }
        catch
        {
            print(error)
        }
    }
    
    class func fetchRequest(for game: Game, type: SaveStateType) -> NSFetchRequest<SaveState>
    {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %d", #keyPath(SaveState.game), game, #keyPath(SaveState.type), type.rawValue)
        
        let fetchRequest: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        fetchRequest.predicate = predicate
        
        return fetchRequest
    }
}

extension SaveState: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \SaveState.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\SaveState.creationDate, \SaveState.filename, \SaveState.modifiedDate, \SaveState.name, \SaveState.type, \SaveState.coreIdentifier]
    }
    
    public var syncableFiles: Set<File> {
        return [File(identifier: "saveState", fileURL: self.fileURL), File(identifier: "thumbnail", fileURL: self.imageFileURL)]
    }
    
    public var syncableRelationships: Set<AnyKeyPath> {
        return [\SaveState.game]
    }
    
    public var isSyncingEnabled: Bool {
        // self.game may be nil if being downloaded, so don't enforce it.
        // guard let identifier = self.game?.identifier else { return false }
        
        let isSyncingEnabled = (self.type != .auto && self.type != .quick) && (self.game?.identifier != Game.melonDSBIOSIdentifier && self.game?.identifier != Game.melonDSDSiBIOSIdentifier)
        return isSyncingEnabled
    }
    
    public var syncableMetadata: [HarmonyMetadataKey : String] {
        guard let game = self.game else { return [:] }
        return [.gameID: game.identifier, .gameName: game.name, .coreID: self.coreIdentifier].compactMapValues { $0 }
    }
    
    public var syncableLocalizedName: String? {
        return self.localizedName
    }
    
    public func awakeFromSync(_ record: AnyRecord)
    {
        guard self.coreIdentifier == nil else { return }
        guard let game = self.game, let system = System(gameType: game.type) else { return }
           
        if let coreIdentifier = record.remoteMetadata?[.coreID]
        {
            // SaveState was synced to older version of Delta and lost its coreIdentifier,
            // but it remains in the remote metadata so we can reassign it.
            self.coreIdentifier = coreIdentifier
        }
        else
        {
            switch system
            {
            case .ds: self.coreIdentifier = DS.core.identifier // Assume DS save state with nil coreIdentifier is from DeSmuME core.
            default: self.coreIdentifier = system.deltaCore.identifier
            }
        }
    }
}
