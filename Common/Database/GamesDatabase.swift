//
//  GamesDatabase.swift
//  Delta
//
//  Created by Riley Testut on 11/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import SQLite

class GamesDatabase
{
    private let connection: Connection
    
    init(fileURL: URL) throws
    {
        self.connection = try Connection(fileURL.path)
    }
    
    func artworkURL(for game: Game) -> URL?
    {
        let roms = Table("ROMs")
        let releases = Table("RELEASES")
        
        let hash = Expression<String>("romHashSHA1")
        let romID = Expression<Int>("romID")
        let artworkAddress = Expression<String?>("releaseCoverFront")
        
        let gameHash = game.identifier.uppercased()
        let query = roms.select(artworkAddress).filter(hash == gameHash).join(releases, on: roms[romID] == releases[romID])
        
        do
        {
            if let row = try self.connection.pluck(query), let address = row[artworkAddress]
            {
                let url = URL(string: address)
                return url
            }
        }
        catch
        {
            print(error)
        }
        
        return nil
    }
}
