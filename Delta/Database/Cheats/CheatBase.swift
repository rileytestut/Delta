//
//  CheatBase.swift
//  Delta
//
//  Created by Riley Testut on 1/17/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import SQLite

import Roxas

private extension UserDefaults
{
    @NSManaged var previousCheatBaseVersion: Int
}

extension ExpressionType
{
    static var cheatID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("cheatID")
    }
    
    static var cheatName: SQLite.Expression<String> {
        return SQLite.Expression<String>("cheatName")
    }
    
    static var cheatDescription: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("cheatDescription")
    }
    
    static var cheatCode: SQLite.Expression<String> {
        return SQLite.Expression<String>("cheatCode")
    }
    
    static var cheatDeviceID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("cheatDeviceID")
    }
    
    static var cheatActivation: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("cheatActivation")
    }
    
    static var cheatCategoryID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("cheatCategoryID")
    }
    
    static var cheatCategoryName: SQLite.Expression<String> {
        return SQLite.Expression<String>("cheatCategory")
    }
    
    static var cheatCategoryDescription: SQLite.Expression<String> {
        return SQLite.Expression<String>("cheatCategoryDescription")
    }
}


extension Table
{
    static var cheats: Table {
        return Table("CHEATS")
    }
    
    static var cheatCategories: Table {
        return Table("CHEAT_CATEGORIES")
    }
}

@available(iOS 14, *)
class CheatBase: GamesDatabase
{
    static let cheatsVersion = 1
    static var previousCheatsVersion: Int? {
        return UserDefaults.standard.previousCheatBaseVersion
    }
    
    private let connection: Connection
    
    override init() throws
    {
        let fileURL = DatabaseManager.cheatBaseURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw GamesDatabase.Error.doesNotExist }
        
        self.connection = try Connection(fileURL.path)
        
        try super.init()
        
        UserDefaults.standard.previousCheatBaseVersion = CheatBase.cheatsVersion
    }
    
    func cheats(for game: Game) async throws -> [CheatMetadata]?
    {
        let metadata = await withCheckedContinuation { continuation in
            if let context = game.managedObjectContext
            {
                context.perform {
                    let metadata = self.metadata(for: game)
                    continuation.resume(returning: metadata)
                }
            }
            else
            {
                let metadata = self.metadata(for: game)
                continuation.resume(returning: metadata)
            }
        }
        
        guard let romIDValue = metadata?.romID else { return nil }
        
        let cheatID = Expression<Any>.cheatID
        let cheatName = Expression<Any>.cheatName
        let cheatCode = Expression<Any>.cheatCode
        let cheatDescription = Expression<Any>.cheatDescription
        let cheatActivation = Expression<Any>.cheatActivation
        let cheatDeviceID = Expression<Any>.cheatDeviceID
        
        let categoryID = Expression<Any>.cheatCategoryID
        let categoryName = Expression<Any>.cheatCategoryName
        let categoryDescription = Expression<Any>.cheatCategoryDescription
        
        let romID = Expression<Any>.romID
        
        let query = Table.cheats.select(cheatID, cheatName, cheatCode, cheatDescription, cheatActivation, cheatDeviceID, Table.cheats[categoryID], categoryName, categoryDescription)
            .filter(romID == romIDValue)
            .join(Table.cheatCategories, on: Table.cheats[categoryID] == Table.cheatCategories[categoryID])
            .order(cheatName)
        
        let rows = try self.connection.prepare(query)
        
        let results = rows.compactMap { (row) -> CheatMetadata? in
            guard case let deviceID = Int16(row[cheatDeviceID]), let device = CheatDevice(rawValue: deviceID) else { return nil }
            
            let id = row[Table.cheats[categoryID]]
            
            let category = CheatCategory(id: id, name: row[categoryName], categoryDescription: row[categoryDescription])
            let metadata = CheatMetadata(id: row[cheatID], name: row[cheatName], code: row[cheatCode], description: row[cheatDescription], activationHint: row[cheatActivation], device: device, category: category)
            return metadata
        }
        
        return results
    }
}
