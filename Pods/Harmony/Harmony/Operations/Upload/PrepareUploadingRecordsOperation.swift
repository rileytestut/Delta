//
//  PrepareUploadingRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/26/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class PrepareUploadingRecordsOperation: Operation<[AnyRecord], Error>
{
    let records: [AnyRecord]
    
    private let managedObjectContext: NSManagedObjectContext
    
    override var isAsynchronous: Bool {
        return true
    }
    
    init(records: [AnyRecord], coordinator: SyncCoordinator, context: NSManagedObjectContext)
    {
        self.records = records
        self.managedObjectContext = context
        
        super.init(coordinator: coordinator)
    }
    
    override func main()
    {
        super.main()
        
        self.managedObjectContext.perform {
            // Lock records that have relationships which have not yet been uploaded.
            do
            {
                let recordIDs = try Record.remoteRelationshipRecordIDs(for: self.records, in: self.managedObjectContext)
                
                for record in self.records
                {
                    let missingRelationships = record.missingRelationships(in: recordIDs)
                    if !missingRelationships.isEmpty
                    {
                        record.shouldLockWhenUploading = true
                    }
                }
                
                self.result = .success(self.records)
            }
            catch
            {
                self.result = .failure(error)
            }
            
            self.finish()
        }
    }
}
