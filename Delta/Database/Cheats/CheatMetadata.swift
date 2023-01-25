//
//  CheatMetadata.swift
//  Delta
//
//  Created by Riley Testut on 1/17/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

struct CheatCategory: Identifiable, Hashable
{
    var id: Int
    
    var name: String
    var categoryDescription: String
}

@objcMembers // @objcMembers required for NSPredicate-based filtering.
final class CheatMetadata: NSObject, Identifiable
{
    let id: Int
    
    let name: String
    let code: String
    
    let cheatDescription: String?
    let activationHint: String?
    
    let device: CheatDevice
    let category: CheatCategory
    
    init(id: Int, name: String, code: String, description: String?, activationHint: String?, device: CheatDevice, category: CheatCategory)
    {
        self.id = id
        self.name = name
        self.code = code
        self.cheatDescription = description
        self.activationHint = activationHint
        self.device = device
        self.category = category
    }
}
