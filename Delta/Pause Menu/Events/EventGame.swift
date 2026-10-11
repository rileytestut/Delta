//
//  EventGame.swift
//  Delta
//
//  Created by Riley Testut on 10/6/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

struct EventGame: RawRepresentable, Decodable, Hashable, CaseIterable
{
    static let ruby = EventGame(rawValue: "ruby")
    static let sapphire = EventGame(rawValue: "sapphire")
    static let emerald = EventGame(rawValue: "emerald")
    static let fireRed = EventGame(rawValue: "fireRed")
    static let leafGreen = EventGame(rawValue: "leafGreen")
    
    static var allCases: [EventGame] {
        [.ruby, .sapphire, .emerald, .fireRed, .leafGreen]
    }
    
    var rawValue: String
    
    init(rawValue: String)
    {
        self.rawValue = rawValue
    }
    
    var gameIDs: Set<String> {
        switch self
        {
        case .ruby: return Set(UserDefaults.standard.rubyEventGameIDs ?? [])
        case .sapphire: return Set(UserDefaults.standard.sapphireEventGameIDs ?? [])
        case .emerald:  return Set(UserDefaults.standard.emeraldEventGameIDs ?? [])
        case .fireRed: return Set(UserDefaults.standard.fireRedEventGameIDs ?? [])
        case .leafGreen: return Set(UserDefaults.standard.leafGreenEventGameIDs ?? [])
            
        default: return []
        }
    }
}
