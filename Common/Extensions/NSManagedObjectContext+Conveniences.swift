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
}
