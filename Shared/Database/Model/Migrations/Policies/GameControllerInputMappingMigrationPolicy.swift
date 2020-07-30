//
//  GameControllerInputMappingMigrationPolicy.swift
//  Delta
//
//  Created by Riley Testut on 1/30/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

@objc(GameControllerInputMappingMigrationPolicy)
class GameControllerInputMappingMigrationPolicy: NSEntityMigrationPolicy
{
    @objc(migrateIdentifier)
    func migrateIdentifier() -> String
    {
        return UUID().uuidString
    }
}
