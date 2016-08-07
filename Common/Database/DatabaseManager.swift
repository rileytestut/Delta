//
//  DatabaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import CoreData

// Workspace
import Roxas
import DeltaCore

// Pods
import FileMD5Hash

class DatabaseManager
{
    static let sharedManager = DatabaseManager()
    
    let managedObjectContext: NSManagedObjectContext
    
    private let privateManagedObjectContext: NSManagedObjectContext
    private let validationManagedObjectContext: NSManagedObjectContext
    
    // MARK: - Initialization -
    /// Initialization
    
    private init()
    {
        let modelURL = Bundle.main.url(forResource: "Model", withExtension: "momd")
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel!)
        
        self.privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.privateManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        self.privateManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.parent = self.privateManagedObjectContext
        self.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        self.validationManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.validationManagedObjectContext.parent = self.managedObjectContext
        self.validationManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        NotificationCenter.default.addObserver(self, selector: #selector(DatabaseManager.managedObjectContextWillSave(_:)), name: NSNotification.Name.NSManagedObjectContextWillSave, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DatabaseManager.managedObjectContextDidSave(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)

    }
    
    func startWithCompletion(_ completionBlock: ((performingMigration: Bool) -> Void)?)
    {
        DispatchQueue.global(qos: .userInitiated).async {
            
            let storeURL = DatabaseManager.databaseDirectoryURL.appendingPathComponent("Delta.sqlite")

            let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            
            var performingMigration = false
            
            if
                let sourceMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: options),
                let managedObjectModel = self.privateManagedObjectContext.persistentStoreCoordinator?.managedObjectModel
            {
                performingMigration = !managedObjectModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: sourceMetadata)
            }
            
            do
            {
                try self.privateManagedObjectContext.persistentStoreCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
            }
            catch let error as NSError
            {
                if error.code == NSMigrationMissingSourceModelError
                {
                    print("Migration failed. Try deleting \(storeURL)")
                }
                else
                {
                    print(error)
                }
                
                abort()
            }
            
            if let completionBlock = completionBlock
            {
                completionBlock(performingMigration: performingMigration)
            }
        }
    }
    
    // MARK: - Importing -
    /// Importing
    
    func importGamesAtURLs(_ URLs: [URL], withCompletion completion: (([String]) -> Void)?)
    {
        let managedObjectContext = self.backgroundManagedObjectContext()
        managedObjectContext.perform() {
            
            var identifiers: [String] = []
            
            for URL in URLs
            {
                let identifier = FileHash.sha1HashOfFile(atPath: URL.path) as String
                
                let filename = identifier + "." + URL.pathExtension
                
                let game = Game.insertIntoManagedObjectContext(managedObjectContext)
                game.name = URL.deletingPathExtension().lastPathComponent ?? NSLocalizedString("Game", comment: "")
                game.identifier = identifier
                game.filename = filename
                
                let gameCollection = GameCollection.gameSystemCollectionForPathExtension(URL.pathExtension, inManagedObjectContext: managedObjectContext)
                game.type = GameType(rawValue: gameCollection.identifier)
                game.gameCollections.insert(gameCollection)
                
                do
                {
                    let destinationURL = DatabaseManager.gamesDirectoryURL.appendingPathComponent(game.identifier + "." + game.preferredFileExtension)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path)
                    {
                        try FileManager.default.removeItem(at: URL)
                    }
                    else
                    {
                        try FileManager.default.moveItem(at: URL, to: destinationURL)
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
                try managedObjectContext.save()
            }
            catch let error as NSError
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
    
    // MARK: - Background Contexts -
    /// Background Contexts
    
    func backgroundManagedObjectContext() -> NSManagedObjectContext
    {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.parent = self.validationManagedObjectContext
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return managedObjectContext
    }
}

extension DatabaseManager
{
    class var databaseDirectoryURL: URL
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
        self.createDirectoryAtURLIfNeeded(databaseDirectoryURL)
        
        return databaseDirectoryURL
    }
    
    class var gamesDirectoryURL: URL
    {
        let gamesDirectoryURL = DatabaseManager.databaseDirectoryURL.appendingPathComponent("Games")
        self.createDirectoryAtURLIfNeeded(gamesDirectoryURL)
        
        return gamesDirectoryURL
    }
    
    class var saveStatesDirectoryURL: URL
    {
        let saveStatesDirectoryURL = DatabaseManager.databaseDirectoryURL.appendingPathComponent("Save States")
        self.createDirectoryAtURLIfNeeded(saveStatesDirectoryURL)
        
        return saveStatesDirectoryURL
    }
    
    class func saveStatesDirectoryURLForGame(_ game: Game) -> URL
    {
        let gameDirectoryURL = DatabaseManager.saveStatesDirectoryURL.appendingPathComponent(game.identifier)
        self.createDirectoryAtURLIfNeeded(gameDirectoryURL)
        
        return gameDirectoryURL
    }
}

private extension DatabaseManager
{
    // MARK: - Saving -
    
    func save()
    {
        let backgroundTaskIdentifier = RSTBeginBackgroundTask("Save Database Task")
        
        self.validationManagedObjectContext.performAndWait {
            
            do
            {
                try self.validationManagedObjectContext.save()
            }
            catch let error as NSError
            {
                print("Failed to save validation context:", error)
            }
            
            
            // Update main managed object context
            self.managedObjectContext.performAndWait() {
                
                do
                {
                    try self.managedObjectContext.save()
                }
                catch let error as NSError
                {
                    print("Failed to save main context:", error)
                }
                
                
                // Save to disk
                self.privateManagedObjectContext.perform() {
                    
                    do
                    {
                        try self.privateManagedObjectContext.save()
                    }
                    catch let error as NSError
                    {
                        print("Failed to save private context to disk:", error)
                    }
                    
                    RSTEndBackgroundTask(backgroundTaskIdentifier)
                    
                }
                
            }
            
        }
    }
    
    // MARK: - Validation -
    
    func validateManagedObjectContextSave(_ managedObjectContext: NSManagedObjectContext)
    {
        // Remove deleted files from disk
        for object in managedObjectContext.deletedObjects
        {
            var fileURLs = Set<URL>()
            
            let temporaryObject = self.validationManagedObjectContext.object(with: object.objectID)
            switch temporaryObject
            {
            case let game as Game:
                fileURLs.insert(game.fileURL as URL)
                
            case let saveState as SaveState:
                fileURLs.insert(saveState.fileURL as URL)
                fileURLs.insert(saveState.imageFileURL as URL)
                
            default: break
            }
            
            for URL in fileURLs
            {
                do
                {
                    try FileManager.default.removeItem(at: URL)
                }
                catch let error as NSError
                {
                    print(error)
                }
            }
        }
        
        // Remove empty collections
        let collections = GameCollection.instancesWithPredicate(NSPredicate(format: "%K.@count == 0", GameCollection.Attributes.games.rawValue), inManagedObjectContext: self.validationManagedObjectContext, type: GameCollection.self)
        
        for collection in collections
        {
            self.validationManagedObjectContext.delete(collection)
        }
    }
    
    // MARK: - Notifications -
    
    @objc func managedObjectContextWillSave(_ notification: Notification)
    {
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.parent == self.validationManagedObjectContext
        else { return }
        
        self.validationManagedObjectContext.performAndWait {
            self.validateManagedObjectContextSave(managedObjectContext)
        }
    }
    
    @objc func managedObjectContextDidSave(_ notification: Notification)
    {
        guard
            let managedObjectContext = notification.object as? NSManagedObjectContext,
            managedObjectContext.parent == self.validationManagedObjectContext
        else { return }
        
        self.save()
    }
    
    // MARK: - File Management -
    
    class func createDirectoryAtURLIfNeeded(_ URL: Foundation.URL)
    {
        do
        {
            try FileManager.default.createDirectory(at: URL, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
    }
}
