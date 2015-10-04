//
//  DatabaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import CoreData

import Roxas

class DatabaseManager
{
    static let sharedManager = DatabaseManager()
    
    let managedObjectContext: NSManagedObjectContext
    
    private let privateManagedObjectContext: NSManagedObjectContext
    
    private init()
    {
        let modelURL = NSBundle.mainBundle().URLForResource("Model", withExtension: "momd")
        let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL!)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel!)
        
        self.privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        self.privateManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        self.managedObjectContext.parentContext = self.privateManagedObjectContext
    }
    
    func startWithCompletion(completionBlock: ((performingMigration: Bool) -> Void)?)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first!
            let databaseDirectorURL = documentsDirectoryURL.URLByAppendingPathComponent("Games")
            let storeURL = databaseDirectorURL.URLByAppendingPathComponent("Delta.sqlite")
            
            do
            {
                try NSFileManager.defaultManager().createDirectoryAtURL(databaseDirectorURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch
            {
                print(error)
            }
            
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
    
    func save()
    {
        guard self.managedObjectContext.hasChanges || self.privateManagedObjectContext.hasChanges else { return }
        
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
    
}
