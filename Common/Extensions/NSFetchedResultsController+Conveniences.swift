//
//  NSFetchedResultsController+Conveniences.swift
//  Delta
//
//  Created by Riley Testut on 5/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import CoreData

extension NSFetchedResultsController
{
    func performFetchIfNeeded()
    {
        guard self.fetchedObjects == nil else { return }
        
        do
        {
            try self.performFetch()
        }
        catch let error as NSError
        {
            print(error)
        }
    }
}
