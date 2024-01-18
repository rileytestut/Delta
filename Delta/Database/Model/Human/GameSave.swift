//
//  GameSave.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//

import Foundation

import GBCDeltaCore

import Harmony
import Roxas

@objc(GameSave)
public class GameSave: _GameSave 
{
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.modifiedDate = Date()
    }
}

extension GameSave: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \GameSave.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\GameSave.modifiedDate, \GameSave.sha1]
    }
    
    public var syncableRelationships: Set<AnyKeyPath> {
        return [\GameSave.game]
    }
    
    public var syncableFiles: Set<File> {
        guard let game = self.game else { return [] }
        
        var files: Set<File> = [File(identifier: "gameSave", fileURL: game.gameSaveURL)]
        
        if game.type == .gbc
        {
            let gameTimeSaveURL = game.gameSaveURL.deletingPathExtension().appendingPathExtension("rtc")
            files.insert(File(identifier: "gameTimeSave", fileURL: gameTimeSaveURL))
        }
        
        return files
    }
    
    public var syncableMetadata: [HarmonyMetadataKey : String] {
        guard let game = self.game else { return [:] }
        
        // Use self.identifier to always link with exact matching game.
        return [.gameID: self.identifier, .gameName: game.name]
    }
    
    public var syncableLocalizedName: String? {
        return self.game?.name
    }
    
    public var isSyncingEnabled: Bool {
        // self.game may be nil if being downloaded, so don't enforce it.
        // guard let identifier = self.game?.identifier else { return false }
        
        return self.game?.identifier != Game.melonDSBIOSIdentifier && self.game?.identifier != Game.melonDSDSiBIOSIdentifier
    }
    
    public func awakeFromSync(_ record: AnyRecord) throws
    {
        do
        {
            guard let game = self.game else { throw SyncValidationError.incorrectGame(nil) }
            
            if game.identifier != self.identifier
            {
                let fetchRequest = GameSave.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(GameSave.identifier), game.identifier)
                
                if let misplacedGameSave = try self.managedObjectContext?.fetch(fetchRequest).first, misplacedGameSave.game == nil
                {
                    // Relink game with its correct gameSave, in case we accidentally misplaced it.
                    // Otherwise, corrupted records might displace already-downloaded GameSaves
                    // due to automatic Core Data relationship propagation, despite us throwing error.
                    game.gameSave = misplacedGameSave
                }
                else
                {
                    // Either there is no misplacedGameSave, or there is but it's linked to another game somehow.
                    game.gameSave = nil
                }
                
                throw SyncValidationError.incorrectGame(game.name)
            }
        }
        catch let error as SyncValidationError
        {
            guard SyncManager.shared.ignoredCorruptedRecordIDs.contains(record.recordID) else { throw error }
            
            let fetchRequest = Game.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), self.identifier)
            
            if let correctGame = try self.managedObjectContext?.fetch(fetchRequest).first
            {
                self.game = correctGame
            }
            else
            {
                throw ValidationError.nilRelationshipObjects(keys: [#keyPath(GameSave.game)])
            }
        }
    }
    
    public func resolveConflict(_ record: AnyRecord) -> ConflictResolution 
    {
        // Only attempt to resolve conflicts for older GameSaves without SHA1 hash (i.e. pre-Delta 1.5)
        guard let game = self.game, self.sha1 == nil else { return .conflict }
        
        do
        {
            let sha1Hash = try RSTHasher.sha1HashOfFile(at: game.gameSaveURL)
            
            // resolveConflict() is called from self.managedObjectContext, so we can update `self` directly
            // and it will be automatically saved once finished conflicting records.
            self.sha1 = sha1Hash
            
            // Don't update localRecord's hash here or else GameSave won't be repaired during initial sync.
            // try localRecord.updateSHA1Hash()
        }
        catch CocoaError.fileNoSuchFile
        {
            // Ignore
        }
        catch
        {
            Logger.sync.error("Failed to update GameSave SHA1 hash when resolving conflict. \(error.localizedDescription, privacy: .public)")
        }
        
        // Conflict for now, but we'll "repair" this record to hopefully resolve conflict.
        return .conflict
    }
}
