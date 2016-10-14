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
    
    private init()
    {
        guard
            let modelURL = Bundle(for: DatabaseManager.self).url(forResource: "Delta", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Core Data model cannot be found. Aborting.") }
        
        super.init(name: "Delta", managedObjectModel: managedObjectModel)
        
        self.viewContext.automaticallyMergesChangesFromParent = true
    }
}

//MARK: - Importing -
/// Importing
extension DatabaseManager
{
    func importGames(at urls: [URL], completion: (([String]) -> Void)?)
    {
        self.performBackgroundTask { (context) in
            
            var identifiers: [String] = []
            
            for url in urls
            {
                let identifier = FileHash.sha1HashOfFile(atPath: url.path) as String
                
                let filename = identifier + "." + url.pathExtension
                
                let game = Game.insertIntoManagedObjectContext(context)
                game.name = url.deletingPathExtension().lastPathComponent
                game.identifier = identifier
                game.filename = filename
                
                let gameCollection = GameCollection.gameSystemCollectionForPathExtension(url.pathExtension, inManagedObjectContext: context)
                game.type = GameType(rawValue: gameCollection.identifier)
                game.gameCollections.insert(gameCollection)
                
                do
                {
                    let destinationURL = DatabaseManager.gamesDirectoryURL.appendingPathComponent(game.identifier + "." + game.preferredFileExtension)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path)
                    {
                        try FileManager.default.removeItem(at: url)
                    }
                    else
                    {
                        try FileManager.default.moveItem(at: url, to: destinationURL)
                    }
                    
                    identifiers.append(game.identifier)
                }
                catch
                {
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
            
            if let completion = completion
            {
                completion(identifiers)
            }
            
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
