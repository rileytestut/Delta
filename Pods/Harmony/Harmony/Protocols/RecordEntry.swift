//
//  RecordEntry.swift
//  Harmony
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

public protocol RecordEntry: NSManagedObject
{
    var recordedObjectType: String { get }
    var recordedObjectIdentifier: String { get }
    
    var recordID: RecordID { get }
}

public extension RecordEntry
{
    var recordID: RecordID {
        let recordID = RecordID(type: self.recordedObjectType, identifier: self.recordedObjectIdentifier)
        return recordID
    }
}
