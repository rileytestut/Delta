//
//  ManagedPatron.swift
//  AltStoreCore
//
//  Created by Riley Testut on 4/18/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import CoreData

@objc(ManagedPatron)
public class ManagedPatron: _ManagedPatron
{
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public init(name: String?, identifier: String, isPatreonPatron: Bool, context: NSManagedObjectContext)
    {
        super.init(entity: ManagedPatron.entity(), insertInto: context)
        
        self.name = name
        self.identifier = identifier
        self.isPatreonPatron = isPatreonPatron
    }
}
