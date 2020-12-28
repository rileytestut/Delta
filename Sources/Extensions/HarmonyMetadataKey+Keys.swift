//
//  HarmonyMetadataKey+Keys.swift
//  Harmony
//
//  Created by Riley Testut on 11/5/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Harmony

extension HarmonyMetadataKey
{
    static let gameID = HarmonyMetadataKey("gameID")
    static let gameName = HarmonyMetadataKey("gameName")
    
    // Backwards compatibility
    static let coreID = HarmonyMetadataKey("coreID")
}
