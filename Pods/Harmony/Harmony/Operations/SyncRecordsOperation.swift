//
//  SyncRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 5/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import Roxas

class SyncRecordsOperation: Operation<[Record<NSManagedObject>: Result<Void, RecordError>], SyncError>
{
    let changeToken: Data?
    
    let syncProgress = SyncProgress(parent: nil, userInfo: nil)
    
    private let dispatchGroup = DispatchGroup()
        
    private(set) var updatedChangeToken: Data?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private var recordResults = [Record<NSManagedObject>: Result<Void, RecordError>]()
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(changeToken: Data?, coordinator: SyncCoordinator)
    {
        self.changeToken = changeToken
        
        super.init(coordinator: coordinator)
        
        self.syncProgress.totalUnitCount = 1
        self.operationQueue.maxConcurrentOperationCount = 1
    }
    
    override func main()
    {
        super.main()
        
        self.progress.addChild(self.syncProgress, withPendingUnitCount: 1)
        
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "com.rileytestut.Harmony.SyncRecordsOperation") { [weak self] in
            guard let identifier = self?.backgroundTaskIdentifier else { return }
            UIApplication.shared.endBackgroundTask(identifier)
        }
        
        NotificationCenter.default.post(name: SyncCoordinator.didStartSyncingNotification, object: nil)
        
        let fetchRemoteRecordsOperation = FetchRemoteRecordsOperation(changeToken: self.changeToken, coordinator: self.coordinator, recordController: self.recordController)
        fetchRemoteRecordsOperation.resultHandler = { [weak self] (result) in
            if case .success(_, let changeToken) = result
            {
                self?.updatedChangeToken = changeToken
            }
            
            self?.finish(result, debugTitle: "Fetch Records Result:")
        }
        self.syncProgress.status = .fetchingChanges
        self.syncProgress.addChild(fetchRemoteRecordsOperation.progress, withPendingUnitCount: 0)
        
        let conflictRecordsOperation = ConflictRecordsOperation(coordinator: self.coordinator)
        conflictRecordsOperation.resultHandler = { [weak self, unowned conflictRecordsOperation] (result) in
            self?.finishRecordOperation(conflictRecordsOperation, result: result, debugTitle: "Conflict Result:")
        }
        conflictRecordsOperation.syncProgress = self.syncProgress
        
        let uploadRecordsOperation = UploadRecordsOperation(coordinator: self.coordinator)
        uploadRecordsOperation.resultHandler = { [weak self, unowned uploadRecordsOperation] (result) in
            self?.finishRecordOperation(uploadRecordsOperation, result: result, debugTitle: "Upload Result:")
        }
        uploadRecordsOperation.syncProgress = self.syncProgress
        
        let downloadRecordsOperation = DownloadRecordsOperation(coordinator: self.coordinator)
        downloadRecordsOperation.resultHandler = { [weak self, unowned downloadRecordsOperation] (result) in
            self?.finishRecordOperation(downloadRecordsOperation, result: result, debugTitle: "Download Result:")
        }
        downloadRecordsOperation.syncProgress = self.syncProgress
        
        let deleteRecordsOperation = DeleteRecordsOperation(coordinator: self.coordinator)
        deleteRecordsOperation.resultHandler = { [weak self, unowned deleteRecordsOperation] (result) in
            self?.finishRecordOperation(deleteRecordsOperation, result: result, debugTitle: "Delete Result:")
        }
        deleteRecordsOperation.syncProgress = self.syncProgress
        
        let operations = [fetchRemoteRecordsOperation, conflictRecordsOperation, uploadRecordsOperation, downloadRecordsOperation, deleteRecordsOperation]
        for operation in operations
        {
            self.dispatchGroup.enter()
            self.operationQueue.addOperation(operation)
        }
        
        self.dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
                        
            // Fetch all conflicted records and add conflicted errors for them all to recordResults.
            let context = self.recordController.newBackgroundContext()
            context.performAndWait {
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = ManagedRecord.conflictedRecordsPredicate
                
                do
                {
                    let records = try context.fetch(fetchRequest)
                    
                    for record in records
                    {
                        let record = Record<NSManagedObject>(record)
                        self.recordResults[record] = .failure(RecordError.conflicted(record))
                    }
                }
                catch
                {
                    print(error)
                }
            }
            
            let didFail = self.recordResults.values.contains(where: { (result) in
                switch result
                {
                case .success: return false
                case .failure: return true
                }
            })
            
            if didFail
            {
                self.result = .failure(SyncError.partial(self.recordResults))
            }
            else
            {
                self.result = .success(self.recordResults)
            }            
            
            self.finish()
            
            if UserDefaults.standard.isDebugModeEnabled
            {
                self.recordController.printRecords()
            }
        }
    }
    
    override func finish()
    {
        guard !self.isFinished else { return }
        
        if self.isCancelled
        {
            self.result = .failure(SyncError(GeneralError.cancelled))
        }
        
        super.finish()
        
        if let identifier = self.backgroundTaskIdentifier
        {
            UIApplication.shared.endBackgroundTask(identifier)
            
            self.backgroundTaskIdentifier = nil
        }
    }
}

private extension SyncRecordsOperation
{
    func finish<T, U: HarmonyError>(_ result: Result<T, U>, debugTitle: String)
    {
        do
        {
            _ = try result.get()
            
            let context = self.recordController.newBackgroundContext()
            let recordCount = try context.performAndWait { () -> Int in
                let fetchRequest = ManagedRecord.fetchRequest() as NSFetchRequest<ManagedRecord>
                fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [ConflictRecordsOperation.predicate,
                                                                                            UploadRecordsOperation.predicate,
                                                                                            DownloadRecordsOperation.predicate,
                                                                                            DeleteRecordsOperation.predicate])
                
                let count = try context.count(for: fetchRequest)
                return count
            }
            
            self.syncProgress.totalUnitCount = Int64(recordCount)
        }
        catch let error as HarmonyError
        {
            self.operationQueue.cancelAllOperations()
            
            self.result = .failure(SyncError(error))
            self.finish()
        }
        catch
        {
            fatalError("Non-HarmonyError thrown from SyncRecordsOperation.finish")
        }
        
        self.dispatchGroup.leave()
    }
    
    func finishRecordOperation<R, T>(_ operation: BatchRecordOperation<R, T>, result: Result<[AnyRecord: Result<R, RecordError>], Error>, debugTitle: String)
    {
        // Map operation.recordResults to use Result<Void, RecordError>.
        let recordResults = operation.recordResults.mapValues { (result) in
            result.map { _ in () }
        }
        
        print(debugTitle, result)
        
        do
        {
            for (record, result) in recordResults
            {
                self.recordResults[record] = result
            }
            
            _ = try result.get()
        }
        catch
        {
            self.result = .failure(SyncError.partial(self.recordResults))
            self.finish()
        }
        
        self.dispatchGroup.leave()
    }
}
