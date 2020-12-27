//
//  NSManagedObject+Conveniences.swift
//  Harmony
//
//  Created by Riley Testut on 10/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

extension NSManagedObject
{
    func `in`(_ context: NSManagedObjectContext) -> Self
    {
        let managedObject = context.object(with: self.objectID)
        return unsafeDowncast(managedObject, to: type(of: self))
    }
}
