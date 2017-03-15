//
//  GamesDatabase.swift
//  Delta
//
//  Created by Riley Testut on 11/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import SQLite

extension ExpressionType
{
    static var name: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("releaseTitleName")
    }
    
    static var artworkAddress: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("releaseCoverFront")
    }
    
    static var hash: SQLite.Expression<String> {
        return SQLite.Expression<String>("romHashSHA1")
    }
    
    static var romID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("romID")
    }
}

extension Table
{
    static var roms: Table {
        return Table("ROMs")
    }
    
    static var releases: Table {
        return Table("RELEASES")
    }
}

extension VirtualTable
{
    static var search: VirtualTable {
        return VirtualTable("Search")
    }
}

extension GamesDatabase
{
    enum Error: Swift.Error
    {
        case doesNotExist
        case connection(Swift.Error)
    }
}

class GamesDatabase
{
    fileprivate let connection: Connection
    
    init() throws
    {
        let fileURL = DatabaseManager.gamesDatabaseURL
        
        do
        {
            self.connection = try Connection(fileURL.path)
        }
        catch
        {
            throw Error.connection(error)
        }
    }
    
    func metadataResults(forGameName gameName: String) -> [GameMetadata]
    {
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        
        let query = VirtualTable.search.select(name, artworkAddress).filter(name.match(gameName + "*"))
        
        do
        {
            let rows = try self.connection.prepare(query)
            
            let results = rows.map { row -> GameMetadata in
                let metadata = GameMetadata()
                metadata.name = row[name]
                
                if let address = row[artworkAddress]
                {
                    metadata.artworkURL = URL(string: address)
                }
                
                return metadata
            }
            
            return results
        }
            
        catch SQLite.Result.error(_, let code, _) where code == 1
        {
            // Table does not exist
            
            if self.prepareFTS()
            {
                return self.metadataResults(forGameName: gameName)
            }
        }
        catch
        {
            print(error)
        }
        
        return []
    }
    
    func metadata(for game: Game) -> GameMetadata?
    {
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        let hash = Expression<Any>.hash
        let romID = Expression<Any>.romID
        
        let gameHash = game.identifier.uppercased()
        let query = Table.roms.select(name, artworkAddress).filter(hash == gameHash).join(Table.releases, on: Table.roms[romID] == Table.releases[romID])
        
        do
        {
            if let row = try self.connection.pluck(query)
            {
                let metadata = GameMetadata()
                metadata.name = row[name]
                
                if let address = row[artworkAddress]
                {
                    metadata.artworkURL = URL(string: address)
                }
                
                return metadata
            }
        }
        catch
        {
            print(error)
        }
        
        return nil
    }
}

private extension GamesDatabase
{
    func prepareFTS() -> Bool
    {
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        
        do
        {
            try self.connection.run(VirtualTable.search.create(.FTS4([name, artworkAddress], tokenize: .Unicode61())))
            
            let update = VirtualTable.search.insert(Table.releases.select(name, artworkAddress))
            _ = try self.connection.run(update)
        }
        catch
        {
            print(error)
            return false
        }
        
        return true
    }
}
