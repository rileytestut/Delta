//
//  MergePolicy.swift
//  Harmony
//
//  Created by Riley Testut on 10/2/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData
import Roxas

extension MergePolicy
{
    public enum Error: LocalizedError
    {
        case contextLevelConflict
        
        public var errorDescription: String? {
            switch self
            {
            case .contextLevelConflict:
                return NSLocalizedString("MergePolicy is only intended to work with database-level conflicts.", comment: "")
            }
        }
    }
}

open class MergePolicy: RSTRelationshipPreservingMergePolicy
{
    open override func resolve(constraintConflicts conflicts: [NSConstraintConflict]) throws
    {
        for conflict in conflicts
        {
            guard conflict.databaseObject == nil else { continue }
            guard let conflictingObject = conflict.conflictingObjects.first else { continue }
            
            let model = conflictingObject.entity.managedObjectModel
            let harmonyEntities = model.entities(forConfigurationName: NSManagedObjectModel.Configuration.harmony.rawValue) ?? []
            
            if harmonyEntities.contains(conflictingObject.entity)
            {
                try super.resolve(constraintConflicts: conflicts)
                throw Error.contextLevelConflict
            }
            else
            {
                // Only Harmony managed objects cannot be context-level conflicts;
                // the client's managed objects should _not_ cause us to throw an error.
            }
        }
        
        var remoteFilesByLocalRecord = [LocalRecord: Set<RemoteFile>]()
        
        for conflict in conflicts
        {
            switch conflict.databaseObject
            {
            case let databaseObject as LocalRecord:
                guard
                    let temporaryObject = conflict.conflictingObjects.first as? LocalRecord,
                    temporaryObject.changedValues().keys.contains(#keyPath(LocalRecord.remoteFiles))
                else { continue }
                
                remoteFilesByLocalRecord[databaseObject] = temporaryObject.remoteFiles
                
            default: break
            }
        }
        
        try super.resolve(constraintConflicts: conflicts)
        
        for conflict in conflicts
        {            
            switch conflict.databaseObject
            {
            case let databaseObject as RemoteRecord:
                guard
                    let snapshot = conflict.snapshots.object(forKey: conflict.databaseObject),
                    let previousStatusValue = snapshot[#keyPath(RemoteRecord.status)] as? Int16,
                    let previousStatus = RecordStatus(rawValue: previousStatusValue),
                    let previousVersionIdentifier = snapshot[#keyPath(RemoteRecord.versionIdentifier)] as? String
                else { continue }
                
                // If previous status was normal, and the previous version identifier matches current version identifier, then status should still be normal.
                if previousStatus == .normal, previousVersionIdentifier == databaseObject.version.identifier
                {
                    databaseObject.status = .normal
                }
                
            case let databaseObject as LocalRecord:
                guard let updatedRemoteFiles = remoteFilesByLocalRecord[databaseObject] else { continue }
                let previousRemoteFiles = databaseObject.remoteFiles
                
                for remoteFile in previousRemoteFiles where !updatedRemoteFiles.contains(remoteFile)
                {
                    // Set localRecord to nil for all databaseObject.remoteFiles that are not in remoteFiles so that they will be deleted.
                    remoteFile.localRecord = nil
                    databaseObject.remoteFiles.remove(remoteFile)
                }
                
                for remoteFile in updatedRemoteFiles where !previousRemoteFiles.contains(remoteFile)
                {
                    databaseObject.remoteFiles.insert(remoteFile)
                }
                
                for remoteFile in updatedRemoteFiles.union(previousRemoteFiles)
                {
                    // We _must_ refresh remoteFile, or else Core Data might insert it
                    // into the database a second time, causing unique constraint failures.
                    remoteFile.managedObjectContext?.refresh(remoteFile, mergeChanges: false)
                }
                
            case let databaseObject as ManagedAccount:
                guard
                    let snapshot = conflict.snapshots.object(forKey: conflict.databaseObject),
                    let previousChangeToken = snapshot[#keyPath(ManagedAccount.changeToken)] as? Data
                else { continue }
                
                // If previous change token was non-nil, and the current change token is nil, then restore previous change token.
                if databaseObject.changeToken == nil
                {
                    databaseObject.changeToken = previousChangeToken
                }
                
            default: break
            }
        }
    }
}
