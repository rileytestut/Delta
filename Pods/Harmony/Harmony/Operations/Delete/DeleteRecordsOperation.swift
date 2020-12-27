//
//  DeleteRecordsOperation.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

class DeleteRecordsOperation: BatchRecordOperation<Void, DeleteRecordOperation>
{
    private var syncableFiles = [AnyRecord: Set<File>]()
    
    override class var predicate: NSPredicate {
        return ManagedRecord.deleteRecordsPredicate
    }
    
    override func main()
    {
        self.syncProgress.status = .deleting
        
        super.main()
    }
    
    override func process(_ records: [AnyRecord], in context: NSManagedObjectContext, completionHandler: @escaping (Result<[AnyRecord], Error>) -> Void)
    {
        for record in records
        {
            record.perform { (managedRecord) in
                guard let syncableFiles = managedRecord.localRecord?.recordedObject?.syncableFiles else { return }
                self.syncableFiles[record] = syncableFiles
            }
        }
        
        completionHandler(.success(records))
    }
    
    override func process(_ result: Result<[AnyRecord : Result<Void, RecordError>], Error>, in context: NSManagedObjectContext, completionHandler: @escaping () -> Void)
    {
        guard case .success(let results) = result else { return completionHandler() }
        
        for (record, result) in results
        {
            guard case .success = result else { continue }
            
            guard let files = self.syncableFiles[record] else { continue }
            
            for file in files
            {
                do
                {
                    try FileManager.default.removeItem(at: file.fileURL)
                }
                catch CocoaError.fileNoSuchFile
                {
                    // Ignore
                }
                catch
                {
                    print("Harmony failed to delete file at URL:", file.fileURL)
                }
            }
        }
        
        completionHandler()
    }
}
