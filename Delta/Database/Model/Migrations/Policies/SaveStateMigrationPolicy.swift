//
//  SaveStateMigrationPolicy.swift
//  Delta
//
//  Created by Riley Testut on 9/28/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import struct DSDeltaCore.DS

@objc(SaveStateToSaveStateMigrationPolicy)
class SaveStateToSaveStateMigrationPolicy: NSEntityMigrationPolicy
{
    @objc(migrateSaveStateType:)
    func migrateSaveStateType(_ rawValue: NSNumber) -> NSNumber
    {
        switch rawValue.intValue
        {
        case 0: return NSNumber(value: SaveStateType.auto.rawValue)
        case 1: return NSNumber(value: SaveStateType.general.rawValue)
        case 2: return NSNumber(value: SaveStateType.locked.rawValue)
        default: return rawValue
        }
    }
}

// Delta5 to Delta6
extension SaveStateToSaveStateMigrationPolicy
{
    @objc(defaultCoreIdentifierForGameType:)
    func defaultCoreIdentifier(for gameType: GameType) -> String?
    {
        guard let system = System(gameType: gameType) else { return nil }
        
        switch system
        {
        case .ds: return DS.core.identifier // Assume any existing save state is from DeSmuME.
        default: return system.deltaCore.identifier
        }
    }
}
