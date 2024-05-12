//
//  GameMetadata.swift
//  Delta
//
//  Created by Riley Testut on 2/6/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

// Must be an NSObject subclass so it can be used with RSTCellContentDataSource.
class GameMetadata: NSObject
{
    let releaseID: Int
    let romID: Int
    
    let name: String?
    let artworkURL: URL?
    
    init(releaseID: Int, romID: Int, name: String?, artworkURL: URL?)
    {
        self.releaseID = releaseID
        self.romID = romID
        self.name = name
        self.artworkURL = artworkURL
    }
}

extension GameMetadata
{
    override var hash: Int {
        return self.releaseID.hashValue ^ self.romID.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool
    {
        guard let metadata = object as? GameMetadata else { return false }
        
        return self.releaseID == metadata.releaseID && self.romID == metadata.romID
    }
}
