//
//  DeleteRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/23/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DeleteRecordOperation: RecordOperation<Void>
{
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        try super.init(record: record, coordinator: coordinator, context: context)
        
        // Remote record = 2 units, local record = 1 unit.
        self.progress.totalUnitCount = 3
    }
    
    override func main()
    {
        super.main()
        
        self.deleteRemoteFiles { (result) in
            do
            {
                try result.get()
                
                self.deleteRemoteRecord { (result) in
                    do
                    {
                        try result.get()
                        
                        self.deleteManagedRecord { (result) in
                            self.result = result
                            self.finish()
                        }
                    }
                    catch
                    {
                        self.result = result
                        self.finish()
                    }
                }
            }
            catch
            {
                self.result = result
                self.finish()
            }
        }
    }
}

private extension DeleteRecordOperation
{
    func deleteRemoteFiles(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        self.record.perform { (managedRecord) -> Void in
            // If local record doesn't exist, we don't treat it as an error and just say it succeeded.
            guard let localRecord = managedRecord.localRecord else { return completionHandler(.success) }
            
            let filesProgress = Progress(totalUnitCount: Int64(localRecord.remoteFiles.count), parent: self.progress, pendingUnitCount: 2)
            
            var errors = [FileError]()
            let dispatchGroup = DispatchGroup()
            
            for remoteFile in localRecord.remoteFiles
            {
                dispatchGroup.enter()
                
                let operation = ServiceOperation<Void, FileError>(coordinator: self.coordinator) { (completionHandler) -> Progress? in
                    return remoteFile.managedObjectContext?.performAndWait {
                        return self.service.delete(remoteFile, completionHandler: completionHandler)
                    }
                }
                operation.resultHandler = { (result) in
                    do
                    {
                        try result.get()
                    }
                    catch FileError.doesNotExist
                    {
                        // Ignore
                    }
                    catch let error as FileError
                    {
                        errors.append(error)
                    }
                    catch
                    {
                        errors.append(FileError(remoteFile.identifier, error))
                    }
                    
                    dispatchGroup.leave()
                }

                filesProgress.addChild(operation.progress, withPendingUnitCount: 1)
                
                self.operationQueue.addOperation(operation)
            }
            
            dispatchGroup.notify(queue: .global()) {
                self.managedObjectContext.perform {
                    if !errors.isEmpty
                    {
                        completionHandler(.failure(.filesFailed(self.record, errors)))
                    }
                    else
                    {
                        completionHandler(.success)
                    }
                }
            }
        }
    }
    
    func deleteRemoteRecord(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        let operation = ServiceOperation(coordinator: self.coordinator) { (completionHandler) -> Progress? in
            return self.service.delete(self.record, completionHandler: completionHandler)
        }
        operation.resultHandler = { (result) in
            do
            {
                try result.get()
                
                completionHandler(.success)
            }
            catch RecordError.doesNotExist
            {
                completionHandler(.success)
            }
            catch
            {
                completionHandler(.failure(RecordError(self.record, error)))
            }
        }

        self.progress.addChild(operation.progress, withPendingUnitCount: 1)
        self.operationQueue.addOperation(operation)
    }
    
    func deleteManagedRecord(completionHandler: @escaping (Result<Void, RecordError>) -> Void)
    {
        self.record.perform(in: self.managedObjectContext) { (managedRecord) in
            if let recordedObject = managedRecord.localRecord?.recordedObject
            {
                self.managedObjectContext.delete(recordedObject)
            }
            
            self.managedObjectContext.delete(managedRecord)
            
            self.progress.completedUnitCount += 1
            
            completionHandler(.success)
        }
    }
}
