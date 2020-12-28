//
//  Record.swift
//  Harmony
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import CoreData

@objc public enum RecordStatus: Int16, CaseIterable
{
    case normal
    case updated
    case deleted
}

public typealias AnyRecord = Record<NSManagedObject>

public struct RecordID: Hashable, Codable, CustomStringConvertible
{
    public var type: String
    public var identifier: String
    
    public var description: String {
        return self.type + "-" + self.identifier
    }
    
    public init(type: String, identifier: String)
    {
        self.type = type
        self.identifier = identifier
    }
}

public class Record<T: NSManagedObject>
{
    public let recordID: RecordID
    
    private let managedRecord: ManagedRecord
    private let managedRecordContext: NSManagedObjectContext?
    
    public var localizedName: String? {
        return self.perform { $0.localRecord?.recordedObject?.syncableLocalizedName ?? $0.remoteRecord?.localizedName }
    }
    
    public var localMetadata: [HarmonyMetadataKey: String]? {
        return self.perform { $0.localRecord?.recordedObject?.syncableMetadata }
    }
    
    public var remoteMetadata: [HarmonyMetadataKey: String]? {
        return self.perform { $0.remoteRecord?.metadata }
    }
    
    public var isConflicted: Bool {
        return self.perform { $0.isConflicted }
    }
    
    public var isSyncingEnabled: Bool {
        return self.perform { $0.isSyncingEnabled }
    }
    
    public var localStatus: RecordStatus? {
        return self.perform { $0.localRecord?.status }
    }
    
    public var remoteStatus: RecordStatus? {
        return self.perform { $0.remoteRecord?.status }
    }
    
    public var remoteVersion: Version? {
        return self.perform { $0.remoteRecord?.version }
    }
    
    public var remoteAuthor: String? {
        return self.perform { $0.remoteRecord?.author }
    }
    
    public var localModificationDate: Date? {
        return self.perform { $0.localRecord?.modificationDate }
    }
    
    var shouldLockWhenUploading = false
    
    init(_ managedRecord: ManagedRecord)
    {
        self.managedRecord = managedRecord
        self.managedRecordContext = managedRecord.managedObjectContext
        
        let recordID: RecordID
        
        if let context = self.managedRecordContext
        {
            recordID = context.performAndWait { managedRecord.recordID }
        }
        else
        {
            recordID = managedRecord.recordID
        }

        self.recordID = recordID
    }
}

extension Record
{
    public func perform<T>(in context: NSManagedObjectContext? = nil, closure: @escaping (ManagedRecord) -> T) -> T
    {
        if let context = context ?? self.managedRecordContext
        {
            return context.performAndWait {
                let record = self.managedRecord.in(context)
                return closure(record)
            }
        }
        else
        {
            return closure(self.managedRecord)
        }
    }
    
    public func perform<T>(in context: NSManagedObjectContext? = nil, closure: @escaping (ManagedRecord) throws -> T) throws -> T
    {
        if let context = context ?? self.managedRecordContext
        {
            return try context.performAndWait {
                let record = self.managedRecord.in(context)
                return try closure(record)
            }
        }
        else
        {
            return try closure(self.managedRecord)
        }
    }
}

public extension Record where T == NSManagedObject
{
    var recordedObject: Syncable? {
        return self.perform { $0.localRecord?.recordedObject }
    }
    
    convenience init<R>(_ record: Record<R>)
    {
        let managedRecord = record.perform { $0 }
        self.init(managedRecord)
    }
}

public extension Record where T: Syncable
{
    var recordedObject: T? {
        return self.perform { $0.localRecord?.recordedObject as? T }
    }
}

public extension Record
{
    func setSyncingEnabled(_ syncingEnabled: Bool) throws
    {
        let result = self.perform { (managedRecord) -> Result<Void, Error> in
            do
            {
                managedRecord.isSyncingEnabled = syncingEnabled
                
                try managedRecord.managedObjectContext?.save()
                
                return .success
            }
            catch
            {
                return .failure(error)
            }
        }
        
        try result.get()
    }
}

extension Record: Hashable
{
    public static func ==(lhs: Record, rhs: Record) -> Bool
    {
        return lhs.recordID == rhs.recordID
    }
    
    public func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.recordID)
    }
}
