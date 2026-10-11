//
//  Event.swift
//  Delta
//
//  Created by Natalie Pekker on 9/22/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

struct Event: Identifiable, Hashable, Decodable
{
    var id: String
    var date: Date

    var name: String
    var summary: String
    var detailedDescription: String

    var imageURL: URL?
    var patchURL: URL?
    
    var minVersion: String?
    var isPatronEvent: Bool
    
    var games: Set<EventGame>
    
    private enum CodingKeys: String, CodingKey
    {
        case id
        case date
        case name
        case summary
        case detailedDescription
        case imageURL
        case patchURL
        case minVersion
        case isPatronEvent = "patron"
        case games
    }
}
