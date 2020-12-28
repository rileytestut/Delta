//
//  RecordRepresentation.swift
//  Harmony
//
//  Created by Riley Testut on 10/10/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

public class RecordRepresentation: NSManagedObject, RecordEntry
{
    @NSManaged public internal(set) var recordedObjectType: String
    @NSManaged public internal(set) var recordedObjectIdentifier: String
    
    @NSManaged public var managedRecord: ManagedRecord?
    
    @NSManaged var sha1Hash: String
    
    @objc public var status: RecordStatus {
        get {
            self.willAccessValue(forKey: #keyPath(RecordRepresentation.status))
            defer { self.didAccessValue(forKey: #keyPath(RecordRepresentation.status)) }
            
            let rawValue = (self.primitiveValue(forKey: #keyPath(RecordRepresentation.status)) as? Int16) ?? 0
            let status = RecordStatus(rawValue: rawValue) ?? .updated
            return status
        }
        set {
            self.willChangeValue(forKey: #keyPath(RecordRepresentation.status))
            defer { self.didChangeValue(forKey: #keyPath(RecordRepresentation.status)) }
            
            self.setPrimitiveValue(newValue.rawValue, forKey: #keyPath(RecordRepresentation.status))
        }
    }
}
