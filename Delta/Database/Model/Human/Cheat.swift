//
//  Cheat.swift
//  Delta
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

@objc(Cheat)
public class Cheat: _Cheat, CheatProtocol
{    
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: Date
    @NSManaged private var primitiveModifiedDate: Date
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = UUID().uuidString
        let date = Date()
        
        self.primitiveIdentifier = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
}
