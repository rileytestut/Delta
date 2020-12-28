//
//  Syncable.swift
//  Harmony
//
//  Created by Riley Testut on 5/25/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public enum ConflictResolution
{
    case conflict
    case local
    case remote
    case newest
    case oldest
}

public protocol Syncable: NSManagedObject
{
    static var syncablePrimaryKey: AnyKeyPath { get }
    
    var syncableType: String { get }
    
    var syncableKeys: Set<AnyKeyPath> { get }
    var syncableRelationships: Set<AnyKeyPath> { get }
    
    var syncableFiles: Set<File> { get }
    var syncableMetadata: [HarmonyMetadataKey: String] { get }
    
    var syncableLocalizedName: String? { get }
    
    var isSyncingEnabled: Bool { get }
    
    func prepareForSync(_ record: AnyRecord) throws
    func awakeFromSync(_ record: AnyRecord) throws
    
    func resolveConflict(_ record: AnyRecord) -> ConflictResolution
}

public extension Syncable
{
    var syncableType: String {
        guard let type = self.entity.name else { fatalError("SyncableManagedObjects must have a valid entity name.") }
        return type
    }
    
    var syncableFiles: Set<File> {
        return []
    }
    
    var syncableRelationships: Set<AnyKeyPath> {
        return []
    }
    
    var isSyncingEnabled: Bool {
        return true
    }
    
    var syncableLocalizedName: String? {
        return nil
    }
    
    var syncableMetadata: [HarmonyMetadataKey: String] {
        return [:]
    }
    
    func prepareForSync(_ record: AnyRecord)
    {
    }
    
    func awakeFromSync(_ record: AnyRecord)
    {
    }
    
    func resolveConflict(_ record: AnyRecord) -> ConflictResolution
    {
        return .conflict
    }
}

public extension Syncable
{
    internal(set) var syncableIdentifier: String? {
        get {
            guard let keyPath = Self.syncablePrimaryKey.stringValue else { fatalError("Syncable.syncablePrimaryKey must reference an @objc String property.") }
            guard let value = self.value(forKeyPath: keyPath) else { return nil } // Valid to have nil value (for example, if property itself is nil, or self has been deleted).
            guard let identifier = value as? String else { fatalError("Syncable.syncablePrimaryKey must reference an @objc String property.") }
            
            return identifier
        }
        set {
            guard let keyPath = Self.syncablePrimaryKey.stringValue else { fatalError("Syncable.syncablePrimaryKey must reference an @objc String property.") }
            self.setValue(newValue, forKeyPath: keyPath)
        }
    }
}

internal extension Syncable
{
    var syncableRelationshipObjects: [String: Syncable] {
        var relationshipObjects = [String: Syncable]()
        
        for keyPath in self.syncableRelationships
        {
            guard let stringValue = keyPath.stringValue else { continue }
            
            let relationshipObject = self.value(forKeyPath: stringValue) as? Syncable
            relationshipObjects[stringValue] = relationshipObject
        }

        return relationshipObjects
    }
}
