//
//  NSManagedObject+Conveniences.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import CoreData

extension NSManagedObject
{
    class var entityName: String
    {
        return NSStringFromClass(self)
    }
    
    class func insertIntoManagedObjectContext(managedObjectContext: NSManagedObjectContext) -> Self
    {
        return self.insertIntoManagedObjectContext(managedObjectContext, type: self)
    }
    
    private class func insertIntoManagedObjectContext<T>(managedObjectContext: NSManagedObjectContext, type: T.Type) -> T
    {
        let object = NSEntityDescription.insertNewObjectForEntityForName(self.entityName, inManagedObjectContext: managedObjectContext) as! T
        return object
    }
    
    // MARK: - Fetches -
    
    class func fetchRequest() -> NSFetchRequest
    {
        let fetchRequest = NSFetchRequest(entityName: self.entityName)
        return fetchRequest
    }
    
    class func instancesInManagedObjectContext<T: NSManagedObject>(managedObjectContext: NSManagedObjectContext, type: T.Type) -> [T]
    {
        return self.instancesWithPredicate(nil, inManagedObjectContext: managedObjectContext, type: type)
    }
    
    class func instancesWithPredicate<T: NSManagedObject>(predicate: NSPredicate?, inManagedObjectContext managedObjectContext: NSManagedObjectContext, type: T.Type) -> [T]
    {
        let fetchRequest = self.fetchRequest()
        fetchRequest.predicate = predicate
        
        var results: [T] = []
        
        do
        {
            results = try managedObjectContext.executeFetchRequest(fetchRequest) as! [T]
        }
        catch let error as NSError
        {
            print("Error loading", predicate, error)
        }
        
        return results
    }
}
