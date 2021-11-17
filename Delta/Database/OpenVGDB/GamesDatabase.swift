//
//  GamesDatabase.swift
//  Delta
//
//  Created by Riley Testut on 11/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import SQLite

private extension UserDefaults
{
    @NSManaged var previousGamesDatabaseVersion: Int
}

extension ExpressionType
{
    static var name: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("releaseTitleName")
    }
    
    static var artworkAddress: SQLite.Expression<String?> {
        return SQLite.Expression<String?>("releaseCoverFront")
    }
    
    static var sha1Hash: SQLite.Expression<String> {
        return SQLite.Expression<String>("romHashSHA1")
    }
    
    static var romID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("romID")
    }
    
    static var releaseID: SQLite.Expression<Int> {
        return SQLite.Expression<Int>("releaseID")
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
    static let version = 2
    static var previousVersion: Int? {
        return UserDefaults.standard.previousGamesDatabaseVersion
    }
    
    private let connection: Connection
    
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
        
        self.invalidateVirtualTableIfNeeded()
    }
    
    func metadataResults(forGameName gameName: String) -> [GameMetadata]
    {
        let releaseID = Expression<Any>.releaseID
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        
        let query = VirtualTable.search.select(releaseID, name, artworkAddress).filter(name.match(gameName + "*"))
        
        do
        {
            let rows = try self.connection.prepare(query)
            
            let results = rows.map { (row) -> GameMetadata in

                let artworkURL: URL?
                if let address = row[artworkAddress]
                {
                    artworkURL = URL(string: address)
                }
                else
                {
                    artworkURL = nil
                }
                

                let metadata = GameMetadata(identifier: row[releaseID], name: row[name], artworkURL: artworkURL)
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
        let releaseID = Expression<Any>.releaseID
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        
        let sha1Hash = Expression<Any>.sha1Hash
        let romID = Expression<Any>.romID
        
        let gameHash = game.identifier.uppercased()
        let query = Table.roms.select(releaseID, name, artworkAddress).filter(sha1Hash == gameHash).join(Table.releases, on: Table.roms[romID] == Table.releases[romID])
        
        do
        {
            if let row = try self.connection.pluck(query)
            {
                let artworkURL: URL?
                if let address = row[artworkAddress]
                {
                    artworkURL = URL(string: address)
                }
                else
                {
                    artworkURL = nil
                }
                
                let metadata = GameMetadata(identifier: row[releaseID], name: row[name], artworkURL: artworkURL)
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
    func invalidateVirtualTableIfNeeded()
    {
        guard UserDefaults.standard.previousGamesDatabaseVersion != GamesDatabase.version else { return }
        
        do
        {
            try self.connection.run(VirtualTable.search.drop(ifExists: true))
            
            UserDefaults.standard.previousGamesDatabaseVersion = GamesDatabase.version
        }
        catch
        {
            print(error)
        }
    }
    
    func prepareFTS() -> Bool
    {
        let name = Expression<Any>.name
        let artworkAddress = Expression<Any>.artworkAddress
        let releaseID = Expression<Any>.releaseID
        
        do
        {
            try self.connection.run(VirtualTable.search.create(.FTS4([releaseID, name, artworkAddress], tokenize: .Unicode61())))
            
            let update = VirtualTable.search.insert(Table.releases.select(releaseID, name, artworkAddress))
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
