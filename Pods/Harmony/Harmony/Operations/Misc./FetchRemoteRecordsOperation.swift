//
//  FetchRemoteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FetchRemoteRecordsOperation: Operation<(Set<RemoteRecord>, Data), FetchError>
{
    let changeToken: Data?
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(changeToken: Data?, coordinator: SyncCoordinator, recordController: RecordController)
    {
        self.changeToken = changeToken
        
        super.init(coordinator: coordinator)
    }
    
    override func main()
    {
        super.main()
        
        let context = self.recordController.newBackgroundContext()
        
        // Use closure instead of local function so we can capture `self` weakly.
        let finish = { [weak self] (result: Result<(Set<RemoteRecord>, Set<String>?, Data), FetchError>) in
            guard let self = self else { return }
            
            do
            {
                let (updatedRecords, deletedRecordIDs, changeToken) = try result.get()
                
                context.perform {
                    do
                    {
                        var records = updatedRecords
                        
                        if UserDefaults.standard.isDebugModeEnabled
                        {
                            for record in updatedRecords
                            {
                                print("Fetched RecordID: \(record.recordID). Hash: \(record.sha1Hash).")
                            }
                        }                        
                        
                        if let recordIDs = deletedRecordIDs
                        {
                            let updatedRecordsByRecordID = Dictionary(updatedRecords, keyedBy: \.recordID)
                            
                            let childContext = self.recordController.newBackgroundContext(withParent: context)
                            
                            let result = childContext.performAndWait { () -> Result<Set<RemoteRecord>, Error> in
                                do
                                {
                                    let fetchRequest = RemoteRecord.fetchRequest() as NSFetchRequest<RemoteRecord>
                                    fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(RemoteRecord.identifier), recordIDs)
                                    fetchRequest.includesPendingChanges = false
                                    
                                    let fetchedRecords = try childContext.fetch(fetchRequest)
                                    
                                    var deletedRecords = Set<RemoteRecord>()
                                    
                                    for record in fetchedRecords
                                    {
                                        if let updatedRecord = updatedRecordsByRecordID[record.recordID]
                                        {
                                            // Record has been deleted _and_ updated.
                                            
                                            if updatedRecord.identifier == record.identifier
                                            {
                                                // Do nothing, update trumps deletion.
                                            }
                                            else
                                            {
                                                // Deleted and updated remote records have _different_ remote identifiers.
                                                // This means a new record with the same recorded object type/ID was uploaded after deleting the old record.
                                                // In this case, delete the old cached remote record, since the updated one will take its place.
                                                childContext.delete(record)
                                            }
                                        }
                                        else
                                        {
                                            // Record was deleted and _not_ also updated, so just mark it as deleted to handle it later.
                                            record.status = .deleted
                                            
                                            deletedRecords.insert(record)
                                        }
                                    }
                                    
                                    // Save to propagate changes to parent context.
                                    try childContext.save()
                                    
                                    return .success(deletedRecords)
                                }
                                catch
                                {
                                    return .failure(error)
                                }
                            }
                            
                            let deletedRecords = try result.get().map { $0.in(context) }
                            records.formUnion(deletedRecords)
                        }
                        
                        try context.save()
                        
                        self.result = .success((records, changeToken))
                    }
                    catch
                    {
                        self.result = .failure(FetchError(error))
                    }
                    
                    self.finish()
                }
            }
            catch
            {
                self.result = .failure(FetchError(error))
                
                self.finish()
            }
        }
        
        let fetchOperation: Foundation.Operation & ProgressReporting
        
        if let changeToken = self.changeToken
        {
            let operation = ServiceOperation(coordinator: self.coordinator) { (completionHandler) -> Progress? in
                return self.service.fetchChangedRemoteRecords(changeToken: changeToken, context: context, completionHandler: completionHandler)
            }
            operation.resultHandler = { (result) in
                do
                {
                    let (updatedRecords, deletedRecordIDs, changeToken) = try result.get()
                    finish(.success((updatedRecords, deletedRecordIDs, changeToken)))
                }
                catch
                {
                    finish(.failure(FetchError(error)))
                }
            }
            
            fetchOperation = operation
        }
        else
        {
            let operation = ServiceOperation(coordinator: self.coordinator) { (completionHandler) -> Progress? in
                return self.service.fetchAllRemoteRecords(context: context, completionHandler: completionHandler)
            }
            operation.resultHandler = { (result) in
                do
                {
                    let (updatedRecords, changeToken) = try result.get()
                    finish(.success((updatedRecords, nil, changeToken)))
                }
                catch
                {
                    finish(.failure(FetchError(error)))
                }
            }
            
            fetchOperation = operation
        }
        
        self.progress.addChild(fetchOperation.progress, withPendingUnitCount: self.progress.totalUnitCount)
        self.operationQueue.addOperation(fetchOperation)
    }
    
    override func finish()
    {
        self.recordController.processPendingUpdates()
        
        super.finish()
    }
}
