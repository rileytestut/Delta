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
    
    // MARK: - Initialization -
    /// Initialization
    
    private init()
    {
        let modelURL = NSBundle.mainBundle().URLForResource("Model", withExtension: "momd")
        let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL!)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel!)
        
        self.privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        self.privateManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        self.privateManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        self.managedObjectContext.parentContext = self.privateManagedObjectContext
        self.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func startWithCompletion(completionBlock: ((performingMigration: Bool) -> Void)?)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            
            let storeURL = self.databaseDirectoryURL().URLByAppendingPathComponent("Delta.sqlite")

            let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            
            var performingMigration = false
            
            if let sourceMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStoreOfType(NSSQLiteStoreType, URL: storeURL, options: options),
                managedObjectModel = self.privateManagedObjectContext.persistentStoreCoordinator?.managedObjectModel
            {
                performingMigration = !managedObjectModel.isConfiguration(nil, compatibleWithStoreMetadata: sourceMetadata)
            }
            
            do
            {
                try self.privateManagedObjectContext.persistentStoreCoordinator?.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
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
    
    // MARK: - Saving -
    /// Saving
    
    func save()
    {
        let backgroundTaskIdentifier = RSTBeginBackgroundTask("Save Database Task")
        
        self.managedObjectContext.performBlockAndWait() {
            
            do
            {
                try self.managedObjectContext.save()
            }
            catch let error as NSError
            {
                print("Failed to save main context:", error)
            }
            
            self.privateManagedObjectContext.performBlock() {
                
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
    
    // MARK: - Importing -
    /// Importing
    
    func importGamesAtURLs(URLs: [NSURL], withCompletion completion: ([String] -> Void)?)
    {
        let managedObjectContext = self.backgroundManagedObjectContext()
        managedObjectContext.performBlock() {
            
            var identifiers: [String] = []
            
            for URL in URLs
            {
                let game = Game.insertIntoManagedObjectContext(managedObjectContext)
                game.name = URL.URLByDeletingPathExtension?.lastPathComponent ?? NSLocalizedString("Game", comment: "")
                game.identifier = FileHash.sha1HashOfFileAtPath(URL.path)
                game.fileURL = self.gamesDirectoryURL().URLByAppendingPathComponent(game.identifier)
                game.typeIdentifier = Game.typeIdentifierForURL(URL) ?? kUTTypeDeltaGame as String
                
                do
                {
                    try NSFileManager.defaultManager().moveItemAtURL(URL, toURL: game.fileURL)
                    
                    identifiers.append(game.identifier)
                }
                catch
                {
                    game.managedObjectContext?.deleteObject(game)
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
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.parentContext = self.managedObjectContext
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return managedObjectContext
    }
    
    // MARK: - File URLs -
    
    private func databaseDirectoryURL() -> NSURL
    {
        let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first!
        let databaseDirectoryURL = documentsDirectoryURL.URLByAppendingPathComponent("Database")
        
        do
        {
            try NSFileManager.defaultManager().createDirectoryAtURL(databaseDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
        
        return databaseDirectoryURL
    }
    
    private func gamesDirectoryURL() -> NSURL
    {
        let gamesDirectoryURL = self.databaseDirectoryURL().URLByAppendingPathComponent("Games")
        
        do
        {
            try NSFileManager.defaultManager().createDirectoryAtURL(gamesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
        
        return gamesDirectoryURL
    }
}
