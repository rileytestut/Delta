//
//  Contributor.swift
//  Delta
//
//  Created by Riley Testut on 2/3/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

struct Contributor: Identifiable, Decodable
{
    var name: String
    
    var id: String {
        // Use names as identifiers for now.
        return self.name
    }
    
    var url: URL? {
        guard let link = self.link, let url = URL(string: link) else { return nil }
        return url
    }
    private var link: String?
    
    var linkName: String?

    var contributions: [Contribution]
}

struct Contribution: Identifiable, Decodable
{
    var name: String
    
    var id: String {
        // Use names as identifiers for now.
        return self.name
    }
    
    var url: URL? {
        guard let link = self.link, let url = URL(string: link) else { return nil }
        return url
    }
    private var link: String?
}
