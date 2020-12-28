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
    let identifier: Int
    
    let name: String?
    let artworkURL: URL?
    
    init(identifier: Int, name: String?, artworkURL: URL?)
    {
        self.name = name
        self.identifier = identifier
        self.artworkURL = artworkURL
    }
}

extension GameMetadata
{
    override var hash: Int {
        return self.identifier.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool
    {
        guard let metadata = object as? GameMetadata else { return false }
        
        return self.identifier == metadata.identifier
    }
}
