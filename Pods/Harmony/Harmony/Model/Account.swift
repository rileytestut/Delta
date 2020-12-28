//
//  Account.swift
//  Harmony
//
//  Created by Riley Testut on 1/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public struct Account
{
    public var name: String
    public var emailAddress: String?
        
    public init(name: String, emailAddress: String?)
    {
        self.name = name
        self.emailAddress = emailAddress
    }
    
    init(account: ManagedAccount)
    {
        self.name = account.name
        self.emailAddress = account.emailAddress
    }
}
