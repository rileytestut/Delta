//
//  RemoteRecord.swift
//  Harmony
//
//  Created by Riley Testut on 6/10/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

@objc(RemoteRecord)
public class RemoteRecord: RecordRepresentation
{
    /* Properties */
    @NSManaged public var identifier: String
    @NSManaged public var isLocked: Bool
    
    @NSManaged public var author: String?
    @NSManaged public var localizedName: String?
    
    @NSManaged var metadata: [HarmonyMetadataKey: String]
    
    @NSManaged var versionIdentifier: String
    @NSManaged var versionDate: Date
        
    @NSManaged private var previousVersionIdentifier: String?
    @NSManaged private var previousVersionDate: Date?
    
    public var version: Version {
        get {
            let version = Version(identifier: self.versionIdentifier, date: self.versionDate)
            return version
        }
        set {
            self.versionIdentifier = newValue.identifier
            self.versionDate = newValue.date
        }
    }
    
    var previousUnlockedVersion: Version? {
        get {
            guard let identifier = self.previousVersionIdentifier, let date = self.previousVersionDate else { return nil }
            
            let version = Version(identifier: identifier, date: date)
            return version
        }
        set {
            self.previousVersionIdentifier = newValue?.identifier
            self.previousVersionDate = newValue?.date
        }
    }
    
    init(identifier: String, versionIdentifier: String, versionDate: Date, recordedObjectType: String, recordedObjectIdentifier: String, status: RecordStatus, context: NSManagedObjectContext)
    {
        super.init(entity: RemoteRecord.entity(), insertInto: context)
        
        self.identifier = identifier
        
        self.recordedObjectType = recordedObjectType
        self.recordedObjectIdentifier = recordedObjectIdentifier
        
        self.status = status
        
        self.version = Version(identifier: versionIdentifier, date: versionDate)
    }
    
    public convenience init(identifier: String, versionIdentifier: String, versionDate: Date, metadata: [HarmonyMetadataKey: String], status: RecordStatus, context: NSManagedObjectContext) throws
    {
        guard let recordedObjectType = metadata[.recordedObjectType], let recordedObjectIdentifier = metadata[.recordedObjectIdentifier] else { throw ValidationError.invalidMetadata(metadata) }
        
        self.init(identifier: identifier, versionIdentifier: versionIdentifier, versionDate: versionDate, recordedObjectType: recordedObjectType, recordedObjectIdentifier: recordedObjectIdentifier, status: status, context: context)
        
        if let isLocked = metadata[.isLocked], isLocked == "true"
        {
            self.isLocked = true            
        }
        
        if let identifier = metadata[.previousVersionIdentifier], let dateString = metadata[.previousVersionDate], let timeInterval = TimeInterval(dateString)
        {
            let date = Date(timeIntervalSinceReferenceDate: timeInterval)
            self.previousUnlockedVersion = Version(identifier: identifier, date: date)
        }
        
        if let author = metadata[.author]
        {
            self.author = author
        }
        
        if let localizedName = metadata[.localizedName]
        {
            self.localizedName = localizedName
        }
        
        if let sha1Hash = metadata[.sha1Hash]
        {
            self.sha1Hash = sha1Hash
        }
        else
        {
            self.sha1Hash = ""
        }
                
        let filteredMetadata = metadata.filter { !HarmonyMetadataKey.allHarmonyKeys.contains($0.key) }
        self.metadata = filteredMetadata
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.metadata = [:]
    }
}

extension RemoteRecord
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<RemoteRecord>
    {
        return NSFetchRequest<RemoteRecord>(entityName: "RemoteRecord")
    }
}
