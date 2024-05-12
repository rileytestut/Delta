//
//  NSManagedObjectContext+Conveniences.swift
//  Delta
//
//  Created by Riley Testut on 2/8/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import CoreData

extension NSManagedObjectContext
{
    // MARK: - Saving -
    
    func saveWithErrorLogging()
    {
        do
        {
            try self.save()
        }
        catch let error as NSError
        {
            print("Error saving NSManagedObjectContext: ", error, error.userInfo)
        }
    }
    
    // MARK: - Perform -
    
    func performAndWait<T>(_ block: @escaping () -> T) -> T
    {
        var result: T! = nil
        
        self.performAndWait {
            result = block()
        }
        
        return result
    }
    
    func performAndWait<T>(_ block: @escaping () throws -> T) throws -> T
    {
        var result: Result<T, Error>! = nil
        
        self.performAndWait {
            result = Result { try block() }
        }
        
        let value = try result.get()
        return value
    }
}
