//
//  Record+Uploading.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

extension Record
{
    func missingRelationships(in recordIDs: Set<RecordID>) -> [String: RecordID]
    {
        var missingRelationships = [String: RecordID]()
        
        self.perform { (managedRecord) in
            guard let localRecord = managedRecord.localRecord, let recordedObject = localRecord.recordedObject else { return }
            
            for (key, relationshipObject) in recordedObject.syncableRelationshipObjects
            {
                guard let identifier = relationshipObject.syncableIdentifier else { continue }
                
                let recordID = RecordID(type: relationshipObject.syncableType, identifier: identifier)
                
                if !recordIDs.contains(recordID)
                {
                    missingRelationships[key] = recordID
                }
            }
        }
                
        return missingRelationships
    }
    
    class func remoteRelationshipRecordIDs(for records: [Record<T>], in context: NSManagedObjectContext) throws -> Set<RecordID>
    {
        let predicates = records.flatMap { (record) -> [NSPredicate] in
            record.perform { (managedRecord) in
                guard let localRecord = managedRecord.localRecord, let recordedObject = localRecord.recordedObject else { return [] }
                
                let predicates = recordedObject.syncableRelationshipObjects.values.compactMap { (relationshipObject) -> NSPredicate? in
                    guard let identifier = relationshipObject.syncableIdentifier else { return nil }
                    
                    return NSPredicate(format: "%K == %@ AND %K == %@",
                                       #keyPath(RemoteRecord.recordedObjectType), relationshipObject.syncableType,
                                       #keyPath(RemoteRecord.recordedObjectIdentifier), identifier)
                }
                
                return predicates
            }
        }
        
        let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        fetchRequest.propertiesToFetch = [#keyPath(RemoteRecord.recordedObjectType), #keyPath(RemoteRecord.recordedObjectIdentifier)]
        
        do
        {
            let remoteRecords = try context.fetch(fetchRequest)
            
            let recordIDs = Set(remoteRecords.lazy.map { RecordID(type: $0.recordedObjectType, identifier: $0.recordedObjectIdentifier) })
            return recordIDs
        }
        catch
        {
            throw error
        }
    }
}
