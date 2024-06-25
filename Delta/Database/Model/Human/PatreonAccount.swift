//
//  PatreonAccount.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//
//  Heavily based on AltStore's PatreonAccount.
//

import Foundation

@objc(PatreonAccount)
public class PatreonAccount: _PatreonAccount
{
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init(account: PatreonAPI.UserAccount, context: NSManagedObjectContext)
    {
        super.init(entity: PatreonAccount.entity(), insertInto: context)
        
        self.identifier = account.identifier
        self.name = account.name
        self.firstName = account.firstName
        
        if let altstorePledge = account.pledges?.first(where: { $0.campaign?.identifier == PatreonAPI.altstoreCampaignID })
        {
            let isActivePatron = (altstorePledge.status == .active)
            self.isPatron = isActivePatron
            
            let hasBetaAccess = altstorePledge.benefits.contains(where: { $0.identifier == PatreonAPI.Benefit.betaAccessID })
            self.hasBetaAccess = hasBetaAccess
        }
        else
        {
            self.isPatron = false
            self.hasBetaAccess = false
        }
    }
}
