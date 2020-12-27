//
//  HarmonyMetadataKey+Keys.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

extension HarmonyMetadataKey
{
    static let recordedObjectType = HarmonyMetadataKey("harmony_recordedObjectType")
    static let recordedObjectIdentifier = HarmonyMetadataKey("harmony_recordedObjectIdentifier")
    
    static let relationshipIdentifier = HarmonyMetadataKey("harmony_relationshipIdentifier")
    
    static let isLocked = HarmonyMetadataKey("harmony_locked")
    
    static let previousVersionIdentifier = HarmonyMetadataKey("harmony_previousVersionIdentifier")
    static let previousVersionDate = HarmonyMetadataKey("harmony_previousVersionDate")
    
    static let sha1Hash = HarmonyMetadataKey("harmony_sha1Hash")
    
    static let author = HarmonyMetadataKey("harmony_author")
    static let localizedName = HarmonyMetadataKey("harmony_localizedName")
    
    public static var allHarmonyKeys: Set<HarmonyMetadataKey> {
        return [.recordedObjectType, .recordedObjectIdentifier, .relationshipIdentifier,
                .isLocked, .previousVersionIdentifier, .previousVersionDate,
                .sha1Hash, .author, .localizedName]
    }
}
