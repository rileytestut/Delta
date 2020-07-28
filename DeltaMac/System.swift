//
//  System.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import DeltaCore
import GBADeltaCore

extension GameType
{
    static let nes = GameType("nes")
    static let snes = GameType("snes")
    static let n64 = GameType("n64")
    static let gbc = GameType("gbc")
    static let ds = GameType("ds")
}

struct Game: GameProtocol, Identifiable, Hashable
{
    var name: String
    var type: GameType
    var fileURL: URL
    
    var id: URL {
        return self.fileURL.appendingPathComponent(self.name)
    }
}

enum System: CaseIterable, Identifiable, Comparable
{
    case nes
    case snes
    case n64
    case gbc
    case gba
    case ds
    
    var id: System {
        return self
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool
    {
        return lhs.year < rhs.year
    }
    
    var placeholderGames: [Game] {
        let placeholderURL = URL(fileURLWithPath: "/Users/riley/Library/Containers/com.rileytestut.DeltaMac/Data/Documents/Emerald.gba")
        
        switch self
        {
        case .nes: return [
            Game(name: "Super Mario Bros.", type: .nes, fileURL: placeholderURL),
            Game(name: "The Legend of Zelda", type: .nes, fileURL: placeholderURL),
            Game(name: "Duck Hunt", type: .nes, fileURL: placeholderURL),
        ]
        case .snes: return [
            Game(name: "Super Mario World", type: .snes, fileURL: placeholderURL),
            Game(name: "Super Metroid", type: .snes, fileURL: placeholderURL),
            Game(name: "Chrono Trigger", type: .snes, fileURL: placeholderURL),
        ]
        case .n64: return [
            Game(name: "Super Mario 64", type: .n64, fileURL: placeholderURL),
            Game(name: "Ocarina of Time", type: .n64, fileURL: placeholderURL),
            Game(name: "Pokemon Snap", type: .n64, fileURL: placeholderURL),
        ]
        case .gbc: return [
            Game(name: "Tetris", type: .gbc, fileURL: placeholderURL),
            Game(name: "Pokemon Yellow", type: .gbc, fileURL: placeholderURL),
            Game(name: "Warioland", type: .gbc, fileURL: placeholderURL),
        ]
        case .gba: return [
            Game(name: "Pokemon Emerald", type: .gba, fileURL: placeholderURL),
            Game(name: "Mario Kart: Super Circuit", type: .gba, fileURL: placeholderURL),
            Game(name: "WarioWare: Twisted!", type: .gba, fileURL: placeholderURL),
        ]
        case .ds: return [
            Game(name: "Pokemon Diamon", type: .ds, fileURL: placeholderURL),
            Game(name: "Kingdom Hearts 358/2 Days", type: .ds, fileURL: placeholderURL),
            Game(name: "New Super Mario Bros.", type: .ds, fileURL: placeholderURL),
        ]
        }
    }
}

extension System
{
    var localizedName: String {
        switch self
        {
        case .nes: return NSLocalizedString("Nintendo Entertainment System", comment: "")
        case .snes: return NSLocalizedString("Super Nintendo Entertainment System", comment: "")
        case .n64: return NSLocalizedString("Nintendo 64", comment: "")
        case .gbc: return NSLocalizedString("Game Boy Color", comment: "")
        case .gba: return NSLocalizedString("Game Boy Advance", comment: "")
        case .ds: return NSLocalizedString("Nintendo DS", comment: "")
        }
    }
    
    var localizedShortName: String {
        switch self
        {
        case .nes: return NSLocalizedString("NES", comment: "")
        case .snes: return NSLocalizedString("SNES", comment: "")
        case .n64: return NSLocalizedString("N64", comment: "")
        case .gbc: return NSLocalizedString("GBC", comment: "")
        case .gba: return NSLocalizedString("GBA", comment: "")
        case .ds: return NSLocalizedString("DS (Beta)", comment: "")
        }
    }
    
    var year: Int {
        switch self
        {
        case .nes: return 1985
        case .snes: return 1990
        case .n64: return 1996
        case .gbc: return 1998
        case .gba: return 2001
        case .ds: return 2004
        }
    }
    
    var gameType: DeltaCore.GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
        case .n64: return .n64
        case .gbc: return .gbc
        case .gba: return .gba
        case .ds: return .ds
        }
    }
}
