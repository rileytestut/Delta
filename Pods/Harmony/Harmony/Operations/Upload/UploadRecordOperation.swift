//
//  UploadRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

import Roxas

class UploadRecordOperation: RecordOperation<RemoteRecord>
{
    private var localRecord: LocalRecord!
    
    required init<T: NSManagedObject>(record: Record<T>, coordinator: SyncCoordinator, context: NSManagedObjectContext) throws
    {
        try super.init(record: record, coordinator: coordinator, context: context)
        
        try self.record.perform { (managedRecord) in
            guard let localRecord = managedRecord.localRecord else {
                throw RecordError(self.record, ValidationError.nilLocalRecord)
            }
            self.localRecord = localRecord
            
            // Record itself = 1 unit, files = 3 units.
            self.progress.totalUnitCount = 4
        }
    }
    
    override func main()
    {
        super.main()
        
        if UserDefaults.standard.isDebugModeEnabled
        {
            print("Started uploading record: ", self.record.recordID)
        }
        
        func upload()
        {
            self.managedObjectContext.perform {
                do
                {
                    let localRecord = self.localRecord.in(self.managedObjectContext)
                    try localRecord.recordedObject?.prepareForSync(self.record)
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                    self.finishUpload()
                    
                    return
                }
                
                self.uploadFiles() { (result) in
                    do
                    {
                        let remoteFiles = try result.get()
                        
                        let localRecord = self.localRecord.in(self.managedObjectContext)
                        let localRecordRemoteFilesByIdentifier = Dictionary(localRecord.remoteFiles, keyedBy: \.identifier)
                        
                        for remoteFile in remoteFiles
                        {
                            if let cachedFile = localRecordRemoteFilesByIdentifier[remoteFile.identifier]
                            {
                                localRecord.remoteFiles.remove(cachedFile)
                            }
                            
                            localRecord.remoteFiles.insert(remoteFile)
                        }
                        
                        self.upload(localRecord) { (result) in
                            self.result = result
                            self.finishUpload()
                        }
                    }
                    catch
                    {
                        self.result = .failure(RecordError(self.record, error))
                        self.finishUpload()
                    }
                }
            }
        }
        
        if self.isBatchOperation
        {
            upload()
        }
        else
        {
            let prepareUploadingRecordsOperation = PrepareUploadingRecordsOperation(records: [self.record], coordinator: self.coordinator, context: self.managedObjectContext)
            prepareUploadingRecordsOperation.resultHandler = { (result) in
                do
                {
                    let records = try result.get()
                    
                    guard !records.isEmpty else { throw RecordError.other(self.record, GeneralError.unknown) }
                    
                    upload()
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                    self.finishUpload()
                }
            }
            
            self.operationQueue.addOperation(prepareUploadingRecordsOperation)
        }
    }
    
    override func finish()
    {
        super.finish()
        
        if UserDefaults.standard.isDebugModeEnabled
        {
            print("Finished uploading record: ", self.record.recordID)
        }
    }
}

private extension UploadRecordOperation
{
    func finishUpload()
    {
        if self.isBatchOperation
        {
            self.finish()
        }
        else
        {
            let operation = FinishUploadingRecordsOperation(results: [self.record: self.result!], coordinator: self.coordinator, context: self.managedObjectContext)
            operation.resultHandler = { (result) in
                do
                {
                    let results = try result.get()
                    
                    guard let result = results.values.first else { throw RecordError.other(self.record, GeneralError.unknown) }
                    
                    let tempRemoteRecord = try result.get()
                    
                    try self.managedObjectContext.save()
                    
                    let remoteRecord = tempRemoteRecord.in(self.managedObjectContext)
                    self.result = .success(remoteRecord)
                }
                catch
                {
                    self.result = .failure(RecordError(self.record, error))
                }
                
                self.finish()
            }
            
            self.operationQueue.addOperation(operation)
        }
    }
    
    func uploadFiles(completionHandler: @escaping (Result<Set<RemoteFile>, RecordError>) -> Void)
    {
        self.record.perform { (managedRecord) -> Void in
            guard let localRecord = managedRecord.localRecord else { return completionHandler(.failure(RecordError(self.record, ValidationError.nilLocalRecord))) }
            guard let recordedObject = localRecord.recordedObject else { return completionHandler(.failure(RecordError(self.record, ValidationError.nilRecordedObject))) }
            
            let remoteFilesByIdentifier = Dictionary(localRecord.remoteFiles, keyedBy: \.identifier)
            
            // Suspend operation queue to prevent upload operations from starting automatically.
            self.operationQueue.isSuspended = true
            
            let filesProgress = Progress.discreteProgress(totalUnitCount: 0)
            
            var remoteFiles = Set<RemoteFile>()
            var errors = [FileError]()
            
            let dispatchGroup = DispatchGroup()
            
            for file in recordedObject.syncableFiles
            {
                do
                {
                    let hash = try RSTHasher.sha1HashOfFile(at: file.fileURL)
                    
                    let remoteFile = remoteFilesByIdentifier[file.identifier]
                    guard remoteFile?.sha1Hash != hash else {
                        // Hash is the same, so don't upload file.
                        self.progress.completedUnitCount += 1
                        continue
                    }
                    
                    dispatchGroup.enter()
                    
                    // Hash is either different or file hasn't yet been uploaded, so upload file.
                    let operation = ServiceOperation<RemoteFile, FileError>(coordinator: self.coordinator) { [weak self] (completionHandler) in
                        guard let self = self else {
                            completionHandler(.failure(FileError(file.identifier, GeneralError.unknown)))
                            return nil
                        }
                        
                        return localRecord.managedObjectContext?.performAndWait { () -> Progress in
                            let metadata: [HarmonyMetadataKey: Any] = [.relationshipIdentifier: file.identifier, .sha1Hash: hash]
                            return self.service.upload(file, for: self.record, metadata: metadata, context: self.managedObjectContext, completionHandler: completionHandler)
                        }
                    }
                    operation.resultHandler = { (result) in
                        do
                        {
                            let remoteFile = try result.get()
                            remoteFiles.insert(remoteFile)
                        }
                        catch let error as FileError
                        {
                            errors.append(error)
                        }
                        catch
                        {
                            errors.append(FileError(file.identifier, error))
                        }
                        
                        dispatchGroup.leave()
                    }
                    
                    filesProgress.totalUnitCount += 1
                    filesProgress.addChild(operation.progress, withPendingUnitCount: 1)
                    
                    self.operationQueue.addOperation(operation)
                }
                catch CocoaError.fileNoSuchFile
                {
                    // File doesn't exist (which is valid), so just continue along.
                }
                catch
                {
                    errors.append(FileError(file.identifier, error))
                }
            }
            
            if errors.isEmpty
            {
                self.progress.addChild(filesProgress, withPendingUnitCount: 3)
                
                self.operationQueue.isSuspended = false
            }
            
            dispatchGroup.notify(queue: .global()) {
                self.managedObjectContext.perform {
                    if !errors.isEmpty
                    {
                        completionHandler(.failure(RecordError.filesFailed(self.record, errors)))
                    }
                    else
                    {
                        completionHandler(.success(remoteFiles))
                    }
                }
            }
        }
    }
    
    func upload(_ localRecord: LocalRecord, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void)
    {
        var metadata = localRecord.recordedObject?.syncableMetadata.mapValues { $0 as Any } ?? [:]
        metadata[.recordedObjectType] = localRecord.recordedObjectType
        metadata[.recordedObjectIdentifier] = localRecord.recordedObjectIdentifier
        metadata[.author] = UIDevice.current.name
        metadata[.localizedName] = localRecord.recordedObject?.syncableLocalizedName as Any
        
        if self.record.shouldLockWhenUploading
        {
            metadata[.isLocked] = String(true)
        }
        
        // Keep track of the previous non-locked version, so we can restore to it in case record is locked indefinitely.
        if let remoteRecord = localRecord.managedRecord?.remoteRecord, !remoteRecord.isLocked
        {
            metadata[.previousVersionIdentifier] = remoteRecord.version.identifier
            metadata[.previousVersionDate] = String(remoteRecord.version.date.timeIntervalSinceReferenceDate)
        }
        
        do
        {
            // Always re-calculate hash since the record's files on disk might have changed.
            try localRecord.updateSHA1Hash()
            
            let sha1Hash = localRecord.sha1Hash
            metadata[.sha1Hash] = sha1Hash
                        
            func finish(_ localRecord: LocalRecord, _ remoteRecord: RemoteRecord)
            {
                remoteRecord.status = .normal
                
                let localRecord = localRecord.in(self.managedObjectContext)
                localRecord.version = remoteRecord.version
                localRecord.status = .normal
                localRecord.sha1Hash = sha1Hash
                
                completionHandler(.success(remoteRecord))
            }

            guard sha1Hash != localRecord.managedRecord?.remoteRecord?.sha1Hash else {
                // Hash is the same, so don't upload record.
                self.progress.completedUnitCount += 1
                
                let remoteRecord = localRecord.managedRecord!.remoteRecord! // Safe because sha1Hash must've matched non-nil hash.
                finish(localRecord, remoteRecord)
                
                return
            }
            
            let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            temporaryContext.parent = self.managedObjectContext
            
            self.record.perform(in: temporaryContext) { (managedRecord) in
                let temporaryLocalRecord = localRecord.in(temporaryContext)
                managedRecord.localRecord = temporaryLocalRecord
                
                let record = Record(managedRecord)
                
                let operation = ServiceOperation(coordinator: self.coordinator) { (completionHandler) in
                    return self.service.upload(record, metadata: metadata, context: self.managedObjectContext, completionHandler: completionHandler)
                }
                operation.resultHandler = { (result) in
                    do
                    {
                        let remoteRecord = try result.get()
                        finish(localRecord, remoteRecord)
                    }
                    catch
                    {
                        completionHandler(.failure(RecordError(self.record, error)))
                    }
                }
 
                self.progress.addChild(operation.progress, withPendingUnitCount: 1)
                self.operationQueue.addOperation(operation)
            }
        }
        catch
        {
            self.progress.completedUnitCount += 1
            
            completionHandler(.failure(RecordError(self.record, error)))
        }
    }
}
