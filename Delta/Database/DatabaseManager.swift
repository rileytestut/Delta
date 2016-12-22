//
//  DatabaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

// Workspace
import DeltaCore

// Pods
import FileMD5Hash

final class DatabaseManager: NSPersistentContainer
{
    static let shared = DatabaseManager()
    
    fileprivate let gamesDatabase: GamesDatabase?
    
    private init()
    {
        guard
            let modelURL = Bundle(for: DatabaseManager.self).url(forResource: "Model", withExtension: "mom"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Core Data model cannot be found. Aborting.") }
        
        do
        {
            if let gamesDatabaseURL = Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite")
            {
                self.gamesDatabase = try GamesDatabase(fileURL: gamesDatabaseURL)
            }
            else
            {
                self.gamesDatabase = nil
            }
        }
        catch
        {
            self.gamesDatabase = nil
            print(error)
        }
        
        super.init(name: "Delta", managedObjectModel: managedObjectModel)
        
        self.viewContext.automaticallyMergesChangesFromParent = true
    }
}

extension DatabaseManager
{
    override func newBackgroundContext() -> NSManagedObjectContext
    {
        let context = super.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void)
    {
        super.loadPersistentStores { (description, error) in
            self.prepareDatabase {
                block(description, error)
            }
        }
    }
}

//MARK: - Preparation -
private extension DatabaseManager
{
    func prepareDatabase(completion: @escaping (Void) -> Void)
    {
        self.performBackgroundTask { (context) in
            
            for gameType in GameType.supportedTypes
            {
                guard let deltaControllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: gameType) else { continue }
                
                let controllerSkin = ControllerSkin(context: context)
                controllerSkin.isStandard = true
                controllerSkin.filename = deltaControllerSkin.fileURL.lastPathComponent
                
                controllerSkin.configure(with: deltaControllerSkin)
            }
            
            do
            {
                try context.save()
            }
            catch
            {
                print("Failed to import standard controller skins:", error)
            }
            
            completion()
            
        }
    }
}

//MARK: - Importing -
/// Importing
extension DatabaseManager
{
    func importControllerSkins(at urls: [URL], completion: ((Set<String>) -> Void)?)
    {
        self.performBackgroundTask { (context) in
            
            var identifiers = Set<String>()
            
            for url in urls
            {
                guard let deltaControllerSkin = DeltaCore.ControllerSkin(fileURL: url) else { continue }
                
                let controllerSkin = ControllerSkin(context: context)
                controllerSkin.filename = deltaControllerSkin.identifier + ".deltaskin"
                
                controllerSkin.configure(with: deltaControllerSkin)
                                
                do
                {
                    if FileManager.default.fileExists(atPath: controllerSkin.fileURL.path)
                    {
                        // Normally we'd replace item instead of delete + move, but it's crashing as of iOS 10
                        // FileManager.default.replaceItemAt(controllerSkin.fileURL, withItemAt: url)
                        
                        // Controller skin exists, but we replace it with the new skin
                        try FileManager.default.removeItem(at: controllerSkin.fileURL)
                    }
                    
                    try FileManager.default.moveItem(at: url, to: controllerSkin.fileURL)
                    
                    identifiers.insert(controllerSkin.identifier)
                }
                catch
                {
                    print("Import Controller Skins error:", error)
                    controllerSkin.managedObjectContext?.delete(controllerSkin)
                }
            }
            
            do
            {
                try context.save()
            }
            catch
            {
                print("Failed to save controller skin import context:", error)
                
                identifiers.removeAll()
            }
            
            completion?(identifiers)
        }
    }
    
    func importGames(at urls: [URL], completion: ((Set<String>) -> Void)?)
    {
        self.performBackgroundTask { (context) in
            
            var identifiers = Set<String>()
            
            for url in urls
            {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                
                let identifier = FileHash.sha1HashOfFile(atPath: url.path) as String
                
                let filename = identifier + "." + url.pathExtension
                
                let game = Game.insertIntoManagedObjectContext(context)
                game.name = url.deletingPathExtension().lastPathComponent
                game.identifier = identifier
                game.filename = filename
                game.artworkURL = self.gamesDatabase?.artworkURL(for: game)

                let gameCollection = GameCollection.gameSystemCollectionForPathExtension(url.pathExtension, inManagedObjectContext: context)
                game.type = GameType(rawValue: gameCollection.identifier)
                game.gameCollections.insert(gameCollection)
                
                do
                {
                    let destinationURL = DatabaseManager.gamesDirectoryURL.appendingPathComponent(filename)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path)
                    {
                        // Game already exists, so we choose not to override it and just delete the new game instead
                        try FileManager.default.removeItem(at: url)
                    }
                    else
                    {
                        try FileManager.default.moveItem(at: url, to: destinationURL)
                    }
                    
                    identifiers.insert(game.identifier)
                }
                catch
                {
                    print("Import Games error:", error)
                    game.managedObjectContext?.delete(game)
                }
                
            }
            
            do
            {
                try context.save()
            }
            catch
            {
                print("Failed to save import context:", error)
                
                identifiers.removeAll()
            }
            
            completion?(identifiers)
        }
    }
}

//MARK: - File URLs -
/// File URLs
extension DatabaseManager
{
    override class func defaultDirectoryURL() -> URL
    {
        let documentsDirectoryURL: URL
        
        if UIDevice.current.userInterfaceIdiom == .tv
        {
            documentsDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
        else
        {
            documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
        let databaseDirectoryURL = documentsDirectoryURL.appendingPathComponent("Database")
        self.createDirectory(at: databaseDirectoryURL)
        
        return databaseDirectoryURL
    }

    class var gamesDirectoryURL: URL
    {
        let gamesDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Games")
        self.createDirectory(at: gamesDirectoryURL)
        
        return gamesDirectoryURL
    }
    
    class var saveStatesDirectoryURL: URL
    {
        let saveStatesDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Save States")
        self.createDirectory(at: saveStatesDirectoryURL)
        
        return saveStatesDirectoryURL
    }
    
    class func saveStatesDirectoryURL(for game: Game) -> URL
    {
        let gameDirectoryURL = DatabaseManager.saveStatesDirectoryURL.appendingPathComponent(game.identifier)
        self.createDirectory(at: gameDirectoryURL)
        
        return gameDirectoryURL
    }
    
    class var controllerSkinsDirectoryURL: URL
    {
        let controllerSkinsDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Controller Skins")
        self.createDirectory(at: controllerSkinsDirectoryURL)
        
        return controllerSkinsDirectoryURL
    }
    
    class func controllerSkinsDirectoryURL(for gameType: GameType) -> URL
    {
        let gameTypeDirectoryURL = DatabaseManager.controllerSkinsDirectoryURL.appendingPathComponent(gameType.rawValue)
        self.createDirectory(at: gameTypeDirectoryURL)
        
        return gameTypeDirectoryURL
    }
}

//MARK: - Private -
private extension DatabaseManager
{
    class func createDirectory(at url: URL)
    {
        do
        {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
    }
}
