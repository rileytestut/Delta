//
//  LocalRecord.swift
//  Harmony
//
//  Created by Riley Testut on 5/23/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData
import Roxas

fileprivate extension CodingUserInfoKey
{
    static let isEncodingForHashing = CodingUserInfoKey(rawValue: "isEncodingForHashing")!
}

extension LocalRecord
{
    private enum CodingKeys: String, CodingKey, Codable
    {
        case type
        case identifier
        case record
        case files
        case relationships
        case sha1Hash
    }
    
    private struct AnyKey: CodingKey
    {
        var stringValue: String
        var intValue: Int?
        
        init(stringValue: String)
        {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int)
        {
            return nil
        }
    }
}

@objc(LocalRecord)
public class LocalRecord: RecordRepresentation, Codable
{
    /* Properties */
    @NSManaged var recordedObjectURI: URL
    @NSManaged var modificationDate: Date
    
    @NSManaged var versionIdentifier: String?
    @NSManaged var versionDate: Date?
    
    @NSManaged var additionalProperties: [String: Any]?
    
    /* Relationships */
    @NSManaged var remoteFiles: Set<RemoteFile>
    
    var version: Version? {
        get {
            guard let identifier = self.versionIdentifier, let date = self.versionDate else { return nil }
            
            let version = Version(identifier: identifier, date: date)
            return version
        }
        set {
            self.versionIdentifier = newValue?.identifier
            self.versionDate = newValue?.date
        }
    }
    
    var recordedObject: Syncable? {
        return self.resolveRecordedObject()
    }
    
    var recordedObjectID: NSManagedObjectID? {
        return self.resolveRecordedObjectID()
    }
    
    var downloadedFiles: Set<File>?
    var remoteRelationships: [String: RecordID]?
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init(recordedObject: Syncable, context: NSManagedObjectContext) throws
    {
        super.init(entity: LocalRecord.entity(), insertInto: context)
        
        do
        {
            // Must be after super.init() or else Swift compiler will crash (as of Swift 4.0)
            try self.configure(with: recordedObject)
        }
        catch
        {
            // Initialization failed, so remove self from managed object context.
            context.delete(self)
        }
    }
    
    public required init(from decoder: Decoder) throws
    {
        guard let context = decoder.managedObjectContext else { throw ValidationError.nilManagedObjectContext }
        
        super.init(entity: LocalRecord.entity(), insertInto: context)
        
        // Keep reference in case an error occurs between inserting recorded object and assigning it to self.recordedObject.
        // This way, we can pass it to removeFromContext() to ensure it is properly removed.
        var tempRecordedObject: NSManagedObject?
        
        do
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let recordType = try container.decode(String.self, forKey: .type)
            
            guard
                let entity = NSEntityDescription.entity(forEntityName: recordType, in: context),
                let managedObjectClass = NSClassFromString(entity.managedObjectClassName) as? Syncable.Type,
                let primaryKeyPath = managedObjectClass.syncablePrimaryKey.stringValue
            else { throw ValidationError.unknownRecordType(recordType) }
            
            let identifier = try container.decode(String.self, forKey: .identifier)
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: recordType)
            fetchRequest.predicate = NSPredicate(format: "%K == %@", primaryKeyPath, identifier)
            
            let recordedObject: Syncable
            
            if let managedObject = try context.fetch(fetchRequest).first as? Syncable
            {
                tempRecordedObject = managedObject
                recordedObject = managedObject
            }
            else
            {
                let managedObject = NSManagedObject(entity: entity, insertInto: context)
                
                // Assign to tempRecordedObject immediately before checking if it is a SyncableManagedObject so we can remove it if not.
                tempRecordedObject = managedObject
                
                guard let syncableManagedObject = managedObject as? Syncable else { throw ValidationError.nonSyncableRecordType(recordType) }
                recordedObject = syncableManagedObject
            }
            
            recordedObject.syncableIdentifier = identifier
            
            var additionalProperties = [String: Any]()
            
            let allValues = try container.decode([String: AnyCodable].self, forKey: .record)
            let supportedKeys = Set(recordedObject.syncableKeys.compactMap { $0.stringValue })
            
            let recordContainer = try container.nestedContainer(keyedBy: AnyKey.self, forKey: .record)
            for (key, value) in allValues
            {
                if supportedKeys.contains(key)
                {
                    let value = try recordContainer.decodeManagedValue(forKey: AnyKey(stringValue: key), entity: entity)
                    recordedObject.setValue(value, forKey: key)
                }
                else
                {
                    additionalProperties[key] = value.value
                }
            }
            
            if !additionalProperties.isEmpty
            {
                self.additionalProperties = additionalProperties
            }
            else
            {
                // Explicitly set to nil so it replaces cached value when merging.
                self.additionalProperties = nil
            }
            
            let sha1Hash = try container.decodeIfPresent(String.self, forKey: .sha1Hash)
            
            // Pass in non-nil string to prevent calculating hashes,
            // which would potentially rely on not-yet-connected relationships.
            try self.configure(with: recordedObject, sha1Hash: sha1Hash ?? "")
            
            let remoteFiles = try container.decodeIfPresent(Set<RemoteFile>.self, forKey: .files) ?? []
            let filteredRemoteFiles = remoteFiles.filter { !$0.identifier.isEmpty && !$0.remoteIdentifier.isEmpty }
            
            self.remoteFiles = Set(filteredRemoteFiles)
            self.remoteRelationships = try container.decodeIfPresent([String: RecordID].self, forKey: .relationships)
        }
        catch
        {
            self.removeFromContext(recordedObject: tempRecordedObject)
            
            throw error
        }
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        func sanitized(_ type: String) -> String
        {
            // For some _bizarre_ reason, occasionally Core Data entity names encode themselves as gibberish.
            // To prevent this, we perform a deep copy of the syncableType, which we then encode 🤷‍♂️.
            let syncableType = String(type.lazy.map { $0 })
            return syncableType
        }
        
        try container.encode(sanitized(self.recordedObjectType), forKey: .type)
        try container.encode(self.recordedObjectIdentifier, forKey: .identifier)
        
        guard let recordedObject = self.recordedObject else { throw ValidationError.nilRecordedObject }
        
        var recordContainer = container.nestedContainer(keyedBy: AnyKey.self, forKey: .record)
        
        let syncableKeys = Set(recordedObject.syncableKeys.compactMap { $0.stringValue })
        for key in syncableKeys
        {
            guard let value = recordedObject.value(forKeyPath: key) else { continue }
            
            // Because `value` is statically typed as Any, there is no bridging conversion from Objective-C types such as NSString to their Swift equivalent.
            // Since these Objective-C types don't conform to Codable, the below check always fails:
            // guard let codableValue = value as? Codable else { continue }
            
            // As a workaround, we attempt to encode all syncableKey values, and just ignore the ones that fail.
            do
            {
                try recordContainer.encodeManagedValue(value, forKey: AnyKey(stringValue: key), entity: recordedObject.entity)
            }
            catch EncodingError.invalidValue
            {
                // Ignore, this value doesn't conform to Codable.
            }
            catch
            {
                throw error
            }
        }
        
        for (key, value) in self.additionalProperties ?? [:]
        {
            // Only include additional properties that don't conflict with existing ones.
            guard !syncableKeys.contains(key) else { continue }
            try recordContainer.encode(AnyCodable(value), forKey: AnyKey(stringValue: key))
        }
        
        let relationships = recordedObject.syncableRelationshipObjects.mapValues { (relationshipObject) -> RecordID? in
            guard let identifier = relationshipObject.syncableIdentifier else { return nil }
            
            let relationship = RecordID(type: sanitized(relationshipObject.syncableType), identifier: identifier)
            return relationship
        }
        
        try container.encode(relationships, forKey: .relationships)
        
        if let isEncodingForHashing = encoder.userInfo[.isEncodingForHashing] as? Bool, isEncodingForHashing
        {
            // If encoding for hashing, we need to hash the _local_ files, not the remote files.
            
            var hashes = [String: String]()
            
            for file in recordedObject.syncableFiles
            {
                do
                {
                    let hash = try RSTHasher.sha1HashOfFile(at: file.fileURL)
                    hashes[file.identifier] = hash
                }
                catch CocoaError.fileNoSuchFile
                {
                    // File doesn't exist (which is valid), so just continue along.
                }
            }
            
            try container.encode(hashes, forKey: .files)
        }
        else
        {
            // If encoding for upload, encode self.remoteFiles, as well as our sha1Hash.
            
            try container.encode(self.remoteFiles, forKey: .files)
            try container.encodeIfPresent(self.sha1Hash, forKey: .sha1Hash)
        }
    }
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.modificationDate = Date()
    }
}

extension LocalRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<LocalRecord>
    {
        return NSFetchRequest<LocalRecord>(entityName: "LocalRecord")
    }
    
    func configure(with recordedObject: Syncable, sha1Hash: String? = nil) throws
    {
        guard recordedObject.isSyncingEnabled else { throw ValidationError.nonSyncableRecordedObject(recordedObject) }
        
        guard let recordedObjectIdentifier = recordedObject.syncableIdentifier else { throw ValidationError.invalidSyncableIdentifier }
        
        if recordedObject.objectID.isTemporaryID
        {
            guard let context = recordedObject.managedObjectContext else { throw ValidationError.nilManagedObjectContext }
            try context.obtainPermanentIDs(for: [recordedObject])
        }
        
        self.recordedObjectType = recordedObject.syncableType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        self.recordedObjectURI = recordedObject.objectID.uriRepresentation()
        
        if let sha1Hash = sha1Hash
        {
            self.sha1Hash = sha1Hash
        }
        else
        {
            try self.updateSHA1Hash()
        }
    }
    
    func updateSHA1Hash() throws
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys] // Ensures consistent ordering of keys (and thus consistent hashing).
        encoder.userInfo = [.isEncodingForHashing: true]
        
        let data = try encoder.encode(self)
        
        let sha1Hash = RSTHasher.sha1Hash(of: data)
        self.sha1Hash = sha1Hash
    }
}

private extension LocalRecord
{
    @NSManaged private var primitiveRecordedObjectURI: URL?
    
    func resolveRecordedObjectID() -> NSManagedObjectID?
    {
        guard let persistentStoreCoordinator = self.managedObjectContext?.persistentStoreCoordinator else {
            fatalError("LocalRecord's associated NSPersistentStoreCoordinator must not be nil to retrieve external NSManagedObjectID.")
        }
        
        // Technically, recordedObjectURI may be nil if this is called from inside LocalRecord.init.
        // To prevent edge-case crashes, we manually check if it is nil first.
        // (We don't just turn it into optional via Optional(self.recordedObjectURI) because
        // that crashes when bridging from ObjC).
        guard self.primitiveRecordedObjectURI != nil else { return nil }
        
        // Nil objectID = persistent store does not exist.
        let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: self.recordedObjectURI)
        return objectID
    }
    
    func resolveRecordedObject() -> Syncable?
    {
        guard let managedObjectContext = self.managedObjectContext else {
            fatalError("LocalRecord's managedObjectContext must not be nil to retrieve external NSManagedObject.")
        }
        
        guard let objectID = self.recordedObjectID else { return nil }
        
        do
        {
            let managedObject = try managedObjectContext.existingObject(with: objectID) as? Syncable
            return managedObject
        }
        catch CocoaError.managedObjectReferentialIntegrity
        {
            // Recorded object has been deleted. Ignore error.
            return nil
        }
        catch
        {
            print(error)
            return nil
        }
    }
}

extension LocalRecord
{
    // Removes a LocalRecord that failed to completely download/parse from its managed object context.
    func removeFromContext(recordedObject: NSManagedObject? = nil)
    {
        guard let context = self.managedObjectContext else { return }
        
        context.delete(self)
        
        if let recordedObject = recordedObject ?? self.recordedObject
        {
            if recordedObject.isInserted
            {
                // This is a new recorded object, so we can just delete it.
                context.delete(recordedObject)
            }
            else
            {
                // We're updating an existing recorded object, so we simply discard our changes.
                context.refresh(recordedObject, mergeChanges: false)
            }
        }
    }
}
