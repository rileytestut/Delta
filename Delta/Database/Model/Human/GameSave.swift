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
        return [.gameID: game.identifier, .gameName: game.name]
    }
    
    public var syncableLocalizedName: String? {
        return self.game?.name
    }
    
    public var isSyncingEnabled: Bool {
        // self.game may be nil if being downloaded, so don't enforce it.
        // guard let identifier = self.game?.identifier else { return false }
        
        return self.game?.identifier != Game.melonDSBIOSIdentifier && self.game?.identifier != Game.melonDSDSiBIOSIdentifier
    }
}
