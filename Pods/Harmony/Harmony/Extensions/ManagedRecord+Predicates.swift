//
//  ManagedRecord+Predicates.swift
//  Harmony
//
//  Created by Riley Testut on 10/3/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

extension ManagedRecord
{
    fileprivate enum SyncAction
    {
        case none
        case upload
        case download
        case delete
        case conflict
        
        init(localStatus: RecordStatus?, remoteStatus: RecordStatus?)
        {
            switch (localStatus, remoteStatus)
            {
            case (.normal?, .normal?): self = .none
            case (.normal?, .updated?): self = .download
            case (.normal?, .deleted?): self = .delete
            case (.normal?, nil): self = .upload
                
            case (.updated?, .normal?): self = .upload
            case (.updated?, .updated?): self = .conflict
            case (.updated?, .deleted?): self = .upload
            case (.updated?, nil): self = .upload
                
            case (.deleted?, .normal?): self = .delete
            case (.deleted?, .updated?): self = .download
            case (.deleted?, .deleted?): self = .delete
            case (.deleted?, nil): self = .delete
                
            case (nil, .normal?): self = .download
            case (nil, .updated?): self = .download
            case (nil, .deleted?): self = .delete
            case (nil, nil): self = .delete
            }
        }
    }
}

extension ManagedRecord
{
    class var conflictedRecordsPredicate: NSPredicate {
        let predicate = NSPredicate(format: "%K == YES", #keyPath(ManagedRecord.isConflicted))
        return predicate
    }
    
    class var syncableRecordsPredicate: NSPredicate {
        let predicate = NSPredicate(format: "%K == NO AND %K == YES", #keyPath(ManagedRecord.isConflicted), #keyPath(ManagedRecord.isSyncingEnabled))
        return predicate
    }
    
    class var uploadRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .upload)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
    
    class var downloadRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .download)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
    
    class var deleteRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .delete)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
    
    class var conflictRecordsPredicate: NSPredicate {
        let predicate = self.predicate(for: .conflict)
        let allConflictsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate, self.conflictedUploadsPredicate])
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [allConflictsPredicate, self.syncableRecordsPredicate])
        return compoundPredicate
    }
    
    private class var mismatchedVersionsPredicate: NSPredicate {
        let predicate = NSPredicate(format: "%K != %K", #keyPath(ManagedRecord.localRecord.versionIdentifier), #keyPath(ManagedRecord.remoteRecord.versionIdentifier))
        return predicate
    }
    
    private class var mismatchedHashesPredicate: NSPredicate {
        let predicate = NSPredicate(format: "%K != %K", #keyPath(ManagedRecord.localRecord.sha1Hash), #keyPath(ManagedRecord.remoteRecord.sha1Hash))
        return predicate
    }
    
    private class var conflictedUploadsPredicate: NSPredicate {
        let mismatchedVersionsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.predicate(for: .upload), self.mismatchedVersionsPredicate])
        let mismatchedHashesPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.predicate(for: .none), self.mismatchedHashesPredicate])
        
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [mismatchedVersionsPredicate, mismatchedHashesPredicate])
        return predicate
    }
}

private extension ManagedRecord
{
    class func predicate(for action: SyncAction) -> NSPredicate
    {
        let statuses = self.statuses(for: action)
        
        let predicate = self.predicate(statuses: statuses)
        return predicate
    }
    
    class func statuses(for syncAction: SyncAction) -> [(RecordStatus?, RecordStatus?)]
    {
        // "Hack" to allow compiler to tell us if we miss any potential cases.
        // We make an array of all possible combinations of statues, then filter out all combinations that don't result in the sync action we want.
        let allCases: [RecordStatus?] = RecordStatus.allCases + [nil]
        let statuses = allCases.flatMap { (localStatus) in allCases.map { (localStatus, $0) } }
        
        let filteredStatuses = statuses.filter { (localStatus, remoteStatus) in
            let action = SyncAction(localStatus: localStatus, remoteStatus: remoteStatus)
            return action == syncAction
        }
        
        return filteredStatuses
    }
    
    class func predicate(statuses: [(localStatus: RecordStatus?, remoteStatus: RecordStatus?)]) -> NSPredicate
    {
        let predicates = statuses.map { (localStatus, remoteStatus) -> NSPredicate in
            let predicate: NSPredicate
            
            switch (localStatus, remoteStatus)
            {
            case let (localStatus?, remoteStatus?):
                predicate = NSPredicate(format: "(%K == %d) AND (%K == %d)", #keyPath(ManagedRecord.localRecord.status), localStatus.rawValue, #keyPath(ManagedRecord.remoteRecord.status), remoteStatus.rawValue)
                
            case let (localStatus?, nil):
                predicate = NSPredicate(format: "(%K == %d) AND (%K == nil)", #keyPath(ManagedRecord.localRecord.status), localStatus.rawValue, #keyPath(ManagedRecord.remoteRecord))
                
            case let (nil, remoteStatus?):
                predicate = NSPredicate(format: "(%K == nil) AND (%K == %d)", #keyPath(ManagedRecord.localRecord), #keyPath(ManagedRecord.remoteRecord.status), remoteStatus.rawValue)
                
            case (nil, nil):
                predicate = NSPredicate(format: "(%K == nil) AND (%K == nil)", #keyPath(ManagedRecord.localRecord), #keyPath(ManagedRecord.remoteRecord))
            }
            
            return predicate
        }
        
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        return predicate
    }
}
