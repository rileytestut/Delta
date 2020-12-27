//
//  ManagedAccount.swift
//  Harmony
//
//  Created by Riley Testut on 3/25/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

@objc(ManagedAccount)
class ManagedAccount: NSManagedObject
{
    /* Properties */
    @NSManaged var name: String
    @NSManaged var emailAddress: String?
    
    @NSManaged var serviceIdentifier: String
    
    @NSManaged var changeToken: Data?
        
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init(account: Account, service: Service, context: NSManagedObjectContext)
    {
        super.init(entity: ManagedAccount.entity(), insertInto: context)
        
        self.name = account.name
        self.emailAddress = account.emailAddress
        self.serviceIdentifier = service.identifier
    }
}

extension ManagedAccount
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<ManagedAccount>
    {
        return NSFetchRequest<ManagedAccount>(entityName: "ManagedAccount")
    }
    
    @nonobjc class func currentAccountFetchRequest() -> NSFetchRequest<ManagedAccount>
    {
        let fetchRequest = self.fetchRequest() as NSFetchRequest<ManagedAccount>
        fetchRequest.fetchLimit = 1
        fetchRequest.returnsObjectsAsFaults = false
        
        return fetchRequest
    }
}

