//
//  ConflictRecordOperation.swift
//  Harmony
//
//  Created by Riley Testut on 10/24/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

private enum ConflictAction
{
    case upload
    case download
    case conflict
}

class ConflictRecordOperation: RecordOperation<Void>
{
    override func main()
    {
        super.main()
        
        self.record.perform(in: self.managedObjectContext) { (managedRecord) in
            
            let action: ConflictAction
            
            if
                let remoteRecord = managedRecord.remoteRecord,
                let localRecord = managedRecord.localRecord,
                let recordedObject = localRecord.recordedObject
            {
                let resolution = recordedObject.resolveConflict(self.record)
                switch resolution
                {
                case .conflict: action = .conflict
                case .local: action = .upload
                case .remote: action = .download

                case .newest:
                    if localRecord.modificationDate > remoteRecord.versionDate
                    {
                        action = .upload
                    }
                    else
                    {
                        action = .download
                    }
                    
                case .oldest:
                    if localRecord.modificationDate < remoteRecord.versionDate
                    {
                        action = .upload
                    }
                    else
                    {
                        action = .download
                    }
                }
            }
            else
            {
                action = .conflict
            }
            
            switch action
            {
            case .upload:
                managedRecord.localRecord?.status = .updated
                managedRecord.remoteRecord?.status = .normal
                
            case .download:
                managedRecord.localRecord?.status = .normal
                managedRecord.remoteRecord?.status = .updated
                
            case .conflict:
                managedRecord.isConflicted = true
            }
            
            self.progress.completedUnitCount = 1
            
            self.result = .success
            self.finish()
        }
    }
}
