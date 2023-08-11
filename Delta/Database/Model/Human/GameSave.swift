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
}
