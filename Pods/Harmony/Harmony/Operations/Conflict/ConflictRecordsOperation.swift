//
//  ConflictRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class ConflictRecordsOperation: BatchRecordOperation<Void, ConflictRecordOperation>
{
    override class var predicate: NSPredicate {
        return ManagedRecord.conflictRecordsPredicate
    }
    
    override func main()
    {
        // Not worth having an additional state for just conflicting records.
        self.syncProgress.status = .fetchingChanges
        
        super.main()
    }
}
