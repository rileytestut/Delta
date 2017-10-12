//
//  SaveStateMigrationPolicy.swift
//  Delta
//
//  Created by Riley Testut on 9/28/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

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
