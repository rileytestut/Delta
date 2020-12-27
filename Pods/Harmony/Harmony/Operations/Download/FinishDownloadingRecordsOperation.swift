//
//  FinishRecordDownloadsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class FinishDownloadingRecordsOperation: Operation<[AnyRecord: Result<LocalRecord, RecordError>], Error>
{
    let results: [AnyRecord: Result<LocalRecord, RecordError>]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(results: [AnyRecord: Result<LocalRecord, RecordError>], coordinator: SyncCoordinator, context: NSManagedObjectContext)
    {
        self.results = results
        self.managedObjectContext = context
        
        super.init(coordinator: coordinator)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            var results = self.results
            
            let recordIDs = results.values.reduce(into: Set<RecordID>()) { (recordIDs, result) in
                guard let localRecord = try? result.get(), let relationships = localRecord.remoteRelationships else { return }
                recordIDs.formUnion(relationships.values)
            }
            
            // Use temporary context to prevent fetching objects that may conflict with temporary objects when saving context.
            let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            temporaryContext.parent = self.managedObjectContext
            temporaryContext.perform {
                do
                {
                    let localRecords = try temporaryContext.fetchRecords(for: recordIDs) as [LocalRecord]
                    
                    let keyValuePairs = localRecords.lazy.compactMap { (localRecord) -> (RecordID, Syncable)? in
                        guard let recordedObject = localRecord.recordedObject else { return nil }
                        return (localRecord.recordID, recordedObject)
                    }
                    
                    // Prefer temporary objects to persisted ones for establishing relationships.
                    // This prevents the persisted objects from registering with context and potentially causing conflicts.
                    let relationshipObjects = Dictionary(keyValuePairs, uniquingKeysWith: { return $0.objectID.isTemporaryID ? $0 : $1 })
                    
                    self.managedObjectContext.perform {
                        // Switch back to context so we can modify objects.
                        
                        func handleError(_ error: Error, record: AnyRecord, localRecord: LocalRecord?)
                        {
                            localRecord?.removeFromContext()
                            
                            results[record] = .failure(RecordError(record, error))
                            
                            if let remoteRecordObjectID = record.perform(closure: { $0.remoteRecord?.objectID })
                            {
                                // Reset remoteRecord status to make us retry the download again in the future.
                                let remoteRecord = self.managedObjectContext.object(with: remoteRecordObjectID) as! RemoteRecord
                                remoteRecord.status = .updated
                            }
                        }

                        // Update relationships for all records first.
                        for (record, result) in results
                        {
                            do
                            {
                                let localRecord = try result.get()
                                
                                do
                                {
                                    try self.updateRelationships(for: localRecord, relationshipObjects: relationshipObjects)
                                }
                                catch
                                {
                                    handleError(error, record: record, localRecord: localRecord)
                                }
                            }
                            catch
                            {
                                handleError(error, record: record, localRecord: nil)
                            }
                        }
                        
                        // Perform additional logic now that all relationships have been repaired.
                        for (record, result) in results
                        {
                            // Only process records that don't have errors.
                            guard let localRecord = try? result.get() else { continue }
                            
                            var backupFiles: [File: URL]?
                            
                            do
                            {
                                // Copy existing files to a backup location in case something goes wrong.
                                let files = try self.backupFiles(for: localRecord, record: record)
                                backupFiles = files
                                
                                // Update files after updating relationships (to prevent replacing files prematurely).
                                try self.updateFiles(for: localRecord, record: record)
                                
                                // Awake record after updating files and relationships (since we might need to access them from awakeFromSync).
                                try localRecord.recordedObject?.awakeFromSync(record)
                                
                                // Remove backup files since we no longer need them.
                                self.removeBackupFiles(files)
                            }
                            catch
                            {
                                if let backupFiles = backupFiles
                                {
                                    // Restore backup files since an error did occur.
                                    self.restoreBackupFiles(backupFiles)
                                }
                                    
                                handleError(error, record: record, localRecord: localRecord)
                            }
                        }
                        
                        self.result = .success(results)
                        self.finish()
                    }
                }
                catch
                {
                    self.result = .failure(error)
                    self.finish()
                }
            }
        }
    }
}

private extension FinishDownloadingRecordsOperation
{
    func updateRelationships(for localRecord: LocalRecord, relationshipObjects: [RecordID: Syncable]) throws
    {
        guard let recordedObject = localRecord.recordedObject else { throw ValidationError.nilRecordedObject }
        
        guard let relationships = localRecord.remoteRelationships else { return }
        
        var missingRelationshipKeys = Set<String>()
        
        for (key, recordID) in relationships
        {
            if let relationshipObject = relationshipObjects[recordID]
            {
                let relationshipObject = relationshipObject.in(self.managedObjectContext)
                recordedObject.setValue(relationshipObject, forKey: key)
            }
            else
            {
                missingRelationshipKeys.insert(key)
            }
        }
        
        if !missingRelationshipKeys.isEmpty
        {
            throw ValidationError.nilRelationshipObjects(keys: missingRelationshipKeys)
        }
    }
    
    func updateFiles(for localRecord: LocalRecord, record: AnyRecord) throws
    {
        guard let recordedObject = localRecord.recordedObject else { throw ValidationError.nilRecordedObject }
        
        guard let files = localRecord.downloadedFiles else { return }
        let filesByIdentifier = Dictionary(recordedObject.syncableFiles, keyedBy: \.identifier)
        
        let unknownFiles = files.filter { !filesByIdentifier.keys.contains($0.identifier) }
        for file in unknownFiles
        {
            do
            {
                // File doesn't match any declared file identifiers, so just delete it.
                try FileManager.default.removeItem(at: file.fileURL)
            }
            catch
            {
                print(error)
            }
        }
        
        var fileErrors = [FileError]()
        
        // Replace files.
        for file in files
        {
            guard let destinationURL = filesByIdentifier[file.identifier]?.fileURL else { continue }
            
            do
            {
                if FileManager.default.fileExists(atPath: destinationURL.path)
                {
                    _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: file.fileURL)
                }
                else
                {
                    try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)
                }
            }
            catch
            {
                fileErrors.append(FileError(file.identifier, error))
            }
        }
        
        guard fileErrors.isEmpty else { throw RecordError.filesFailed(record, fileErrors) }
    }
    
    func backupFiles(for localRecord: LocalRecord, record: AnyRecord) throws -> [File: URL]
    {
        guard let recordedObject = localRecord.recordedObject else { throw ValidationError.nilRecordedObject }
        let temporaryURLsByFile = Dictionary(uniqueKeysWithValues: recordedObject.syncableFiles.lazy.map { ($0, FileManager.default.uniqueTemporaryURL()) })
        
        var fileErrors = [FileError]()
        
        for (file, temporaryURL) in temporaryURLsByFile
        {
            do
            {
                try FileManager.default.copyItem(at: file.fileURL, to: temporaryURL)
            }
            catch CocoaError.fileReadNoSuchFile
            {
                // Ignore
            }
            catch
            {
                fileErrors.append(FileError(file.identifier, error))
            }
        }
        
        if !fileErrors.isEmpty
        {
            throw RecordError.filesFailed(record, fileErrors)
        }
        
        return temporaryURLsByFile
    }
    
    func restoreBackupFiles(_ backupFiles: [File: URL])
    {
        for (file, temporaryURL) in backupFiles
        {
            guard FileManager.default.fileExists(atPath: temporaryURL.path) else { continue }
            
            do
            {
                if FileManager.default.fileExists(atPath: file.fileURL.path)
                {
                    _ = try FileManager.default.replaceItemAt(file.fileURL, withItemAt: temporaryURL)
                }
                else
                {
                    try FileManager.default.moveItem(at: temporaryURL, to: file.fileURL)
                }
            }
            catch
            {
                print(error)
            }
        }
    }
    
    func removeBackupFiles(_ backupFiles: [File: URL])
    {
        for (_, temporaryURL) in backupFiles
        {
            guard FileManager.default.fileExists(atPath: temporaryURL.path) else { continue }
            
            do
            {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            catch
            {
                print(error)
            }
        }
    }
}
