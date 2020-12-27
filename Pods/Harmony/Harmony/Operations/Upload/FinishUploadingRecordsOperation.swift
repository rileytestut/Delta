//
//  FinishUploadingRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FinishUploadingRecordsOperation: Operation<[AnyRecord: Result<RemoteRecord, RecordError>], Error>
{
    let results: [AnyRecord: Result<RemoteRecord, RecordError>]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(results: [AnyRecord: Result<RemoteRecord, RecordError>], coordinator: SyncCoordinator, context: NSManagedObjectContext)
    {
        self.results = results
        self.managedObjectContext = context
        
        super.init(coordinator: coordinator)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            // Unlock records that were previously locked, and no longer have relationships that have not yet been uploaded.
            
            var results = self.results
            
            do
            {
                let records = results.compactMap { (record, result) -> AnyRecord? in
                    guard record.shouldLockWhenUploading else { return nil }
                    guard let _ = try? result.get() else { return nil }
                    
                    return record
                }
                
                let recordIDs = try Record.remoteRelationshipRecordIDs(for: records, in: self.managedObjectContext)
                
                var recordsToUnlock = Set<AnyRecord>()
                
                for record in records
                {
                    let missingRelationships = record.missingRelationships(in: recordIDs)
                    if !missingRelationships.isEmpty
                    {
                        results[record] = .failure(RecordError(record, ValidationError.nilRelationshipObjects(keys: Set(missingRelationships.keys))))
                    }
                    else
                    {
                        recordsToUnlock.insert(record)
                    }
                }
                
                let dispatchGroup = DispatchGroup()
                
                let operations = recordsToUnlock.compactMap { (record) -> UpdateRecordMetadataOperation? in
                    record.perform(in: self.managedObjectContext) { (managedRecord) in
                        do
                        {
                            if managedRecord.remoteRecord == nil, let result = results[record], let remoteRecord = try? result.get()
                            {
                                managedRecord.remoteRecord = remoteRecord
                            }
                            
                            let record = AnyRecord(managedRecord)
                            
                            let operation = try UpdateRecordMetadataOperation(record: record, coordinator: self.coordinator, context: self.managedObjectContext)
                            operation.metadata[.isLocked] = NSNull()
                            operation.resultHandler = { (result) in
                                do
                                {
                                    try result.get()
                                }
                                catch
                                {
                                    // Mark record for re-uploading later to unlock remote record.
                                    managedRecord.localRecord?.status = .updated
                                    
                                    results[record] = .failure(RecordError(record, error))
                                }
                                
                                dispatchGroup.leave()
                            }
                            
                            dispatchGroup.enter()
                            
                            return operation
                        }
                        catch
                        {
                            results[record] = .failure(RecordError(record, error))
                            
                            return nil
                        }
                    }
                }
                
                self.operationQueue.addOperations(operations, waitUntilFinished: false)
                
                dispatchGroup.notify(queue: .global()) {
                    self.managedObjectContext.perform {
                        self.result = .success(results)
                        self.finish()
                    }
                }
            }
            catch
            {
                self.managedObjectContext.perform {
                    self.result = .failure(error)
                    self.finish()
                }
            }
        }
    }
}
