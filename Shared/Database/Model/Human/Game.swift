//
//  Game.swift
//  Delta
//
//  Created by Riley Testut on 10/3/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore
import Harmony

public extension Game
{
    static let melonDSBIOSIdentifier = "com.rileytestut.MelonDSDeltaCore.BIOS"
}

@objc(Game)
public class Game: _Game, GameProtocol
{
    public var fileURL: URL {
        var fileURL: URL!
        
        self.managedObjectContext?.performAndWait {
            fileURL = DatabaseManager.gamesDirectoryURL.appendingPathComponent(self.filename)
        }
        
        return fileURL
    }
    
    public override var artworkURL: URL? {
        get {
            self.willAccessValue(forKey: #keyPath(Game.artworkURL))
            var artworkURL = self.primitiveValue(forKey: #keyPath(Game.artworkURL)) as? URL
            self.didAccessValue(forKey: #keyPath(Game.artworkURL))
            
            if let unwrappedArtworkURL = artworkURL
            {
                if unwrappedArtworkURL.isFileURL
                {
                    // Recreate the stored URL relative to current sandbox location.
                    artworkURL = URL(fileURLWithPath: unwrappedArtworkURL.relativePath, relativeTo: DatabaseManager.gamesDirectoryURL)
                }
                else if unwrappedArtworkURL.host?.lowercased() == "img.gamefaqs.net", var components = URLComponents(url: unwrappedArtworkURL, resolvingAgainstBaseURL: false)
                {
                    // Quick fix for broken album artwork URLs due to host change.
                    components.host = "gamefaqs1.cbsistatic.com"
                    components.scheme = "https"
                    
                    if let url = components.url
                    {
                        artworkURL = url
                    }
                }
            }
            
            return artworkURL
        }
        set {
            self.willChangeValue(forKey: #keyPath(Game.artworkURL))
            
            var artworkURL = newValue
            
            if let newValue = newValue, newValue.isFileURL
            {
                // Store a relative URL, since the sandbox location changes.
                artworkURL = URL(fileURLWithPath: newValue.lastPathComponent, relativeTo: DatabaseManager.gamesDirectoryURL)
            }
            
            self.setPrimitiveValue(artworkURL, forKey: #keyPath(Game.artworkURL))
            
            self.didChangeValue(forKey: #keyPath(Game.artworkURL))
        }
    }
    
    public convenience init(name: String, type: GameType, fileURL: URL)
    {
        fatalError("This init is not supported")
    }
}

extension Game
{
    class var recentlyPlayedFetchRequest: NSFetchRequest<Game> {
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Game.playedDate))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.playedDate, ascending: false), NSSortDescriptor(keyPath: \Game.name, ascending: true)]
        fetchRequest.fetchLimit = 4
        
        return fetchRequest
    }
}

extension Game
{
    override public func prepareForDeletion()
    {
        super.prepareForDeletion()
        
        guard let managedObjectContext = self.managedObjectContext else { return }
        
        // If a game with the same identifier is also currently being inserted, Core Data is more than likely resolving a conflict by deleting the previous instance
        // In this case, we make sure we DON'T delete the game file + misc other Core Data relationships, or else we'll just lose all that data
        guard !managedObjectContext.insertedObjects.contains(where: { ($0 as? Game)?.identifier == self.identifier }) else { return }
        
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        
        do
        {
            try FileManager.default.removeItem(at: self.fileURL)
        }
        catch
        {
            print(error)
        }
        
        if let collection = self.gameCollection, collection.games.count == 1
        {
            // Once this game is deleted, collection will have 0 games, so we should delete it
            managedObjectContext.delete(collection)
        }
        
        // Manually cascade deletion since SaveState.fileURL references Game, and so we need to ensure we delete SaveState's before Game
        // Otherwise, we crash when accessing SaveState.game since it is nil
        for saveState in self.saveStates
        {
            managedObjectContext.delete(saveState)
        }
        
        if managedObjectContext.hasChanges
        {
            managedObjectContext.saveWithErrorLogging()
        }
    }
}

extension Game: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \Game.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Game.artworkURL, \Game.filename, \Game.name, \Game.type]
    }
    
    public var syncableFiles: Set<File> {
        let gameFile = File(identifier: "game", fileURL: self.fileURL)
        
        let artworkURL = DatabaseManager.artworkURL(for: self)
        let artworkFile = File(identifier: "artwork", fileURL: artworkURL)
        
        return [gameFile, artworkFile]
    }
    
    public var syncableRelationships: Set<AnyKeyPath> {
        return [\Game.gameCollection]
    }
    
    public var syncableLocalizedName: String? {
        return self.name
    }
    
    public var isSyncingEnabled: Bool {
        return self.identifier != Game.melonDSBIOSIdentifier
    }
}

extension Game: Identifiable
{
    public var id: NSManagedObjectID {
        return self.objectID
    }
}
