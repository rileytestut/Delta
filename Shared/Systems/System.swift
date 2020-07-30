//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

//import SNESDeltaCore
import GBADeltaCore
//import GBCDeltaCore
//import NESDeltaCore
////import N64DeltaCore
//import MelonDSDeltaCore

// Legacy Cores
//import struct DSDeltaCore.DS

extension GameType
{
    static let nes = GameType("nes")
    static let snes = GameType("snes")
    static let n64 = GameType("n64")
    static let gbc = GameType("gbc")
}

enum System: CaseIterable, Identifiable, Comparable
{
    case nes
    case snes
//    case n64
    case gbc
    case gba
    case ds
    
    static var registeredSystems: [System] {
        let systems = System.allCases.filter { Delta.registeredCores.keys.contains($0.gameType) }
        return systems
    }
    
    static var allCores: [DeltaCoreProtocol] {
        #if targetEnvironment(macCatalyst)
        return [GBA.core]
        #else
        return [NES.core, SNES.core, /*N64.core, */ GBC.core, GBA.core, /*DS.core,*/ MelonDS.core]
        #endif
    }
    
    var id: System {
        return self
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool
    {
        return lhs.year < rhs.year
    }
    
    var placeholderGames: [Game] {
        let placeholderURL = URL(fileURLWithPath: "/Users/riley/Library/Containers/com.rileytestut.DeltaMac/Data/Documents/Emerald.gba")
        return []
//
//        switch self
//        {
//        case .nes: return [
//            Game(name: "Super Mario Bros.", type: .nes, fileURL: placeholderURL),
//            Game(name: "The Legend of Zelda", type: .nes, fileURL: placeholderURL),
//            Game(name: "Duck Hunt", type: .nes, fileURL: placeholderURL),
//        ]
//        case .snes: return [
//            Game(name: "Super Mario World", type: .snes, fileURL: placeholderURL),
//            Game(name: "Super Metroid", type: .snes, fileURL: placeholderURL),
//            Game(name: "Chrono Trigger", type: .snes, fileURL: placeholderURL),
//        ]
//        case .n64: return [
//            Game(name: "Super Mario 64", type: .n64, fileURL: placeholderURL),
//            Game(name: "Ocarina of Time", type: .n64, fileURL: placeholderURL),
//            Game(name: "Pokemon Snap", type: .n64, fileURL: placeholderURL),
//        ]
//        case .gbc: return [
//            Game(name: "Tetris", type: .gbc, fileURL: placeholderURL),
//            Game(name: "Pokemon Yellow", type: .gbc, fileURL: placeholderURL),
//            Game(name: "Warioland", type: .gbc, fileURL: placeholderURL),
//        ]
//        case .gba: return [
//            Game(name: "Pokemon Emerald", type: .gba, fileURL: placeholderURL),
//            Game(name: "Mario Kart: Super Circuit", type: .gba, fileURL: placeholderURL),
//            Game(name: "WarioWare: Twisted!", type: .gba, fileURL: placeholderURL),
//        ]
//        case .ds: return [
//            Game(name: "Pokemon Diamon", type: .ds, fileURL: placeholderURL),
//            Game(name: "Kingdom Hearts 358/2 Days", type: .ds, fileURL: placeholderURL),
//            Game(name: "New Super Mario Bros.", type: .ds, fileURL: placeholderURL),
//        ]
//        }
    }
}

extension System
{
    var localizedName: String {
        switch self
        {
        case .nes: return NSLocalizedString("Nintendo", comment: "")
        case .snes: return NSLocalizedString("Super Nintendo", comment: "")
//        case .n64: return NSLocalizedString("Nintendo 64", comment: "")
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
//        case .n64: return NSLocalizedString("N64", comment: "")
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
//        case .n64: return 1996
        case .gbc: return 1998
        case .gba: return 2001
        case .ds: return 2004
        }
    }
}

extension System
{
    #if targetEnvironment(macCatalyst)
    var deltaCore: DeltaCoreProtocol {
        return GBA.core
    }
    #else
    var deltaCore: DeltaCoreProtocol {
        switch self
        {
        case .nes: return NES.core
        case .snes: return SNES.core
//        case .n64: return N64.core
        case .gbc: return GBC.core
        case .gba: return GBA.core
        case .ds: return Settings.preferredCore(for: .ds) ?? MelonDS.core
        }
    }
    #endif
    
    var gameType: DeltaCore.GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
//        case .n64: return .n64
        case .gbc: return .gbc
        case .gba: return .gba
        case .ds: return .ds
        }
    }
    
    init?(gameType: DeltaCore.GameType)
    {
        switch gameType
        {
        case GameType.nes: self = .nes
        case GameType.snes: self = .snes
//        case GameType.n64: self = .n64
        case GameType.gbc: self = .gbc
        case GameType.gba: self = .gba
        case GameType.ds: self = .ds
        default: return nil
        }
    }
}

extension DeltaCore.GameType
{
    init?(fileExtension: String)
    {
        switch fileExtension.lowercased()
        {
        case "nes": self = .nes
        case "smc", "sfc", "fig": self = .snes
//        case "n64", "z64": self = .n64
        case "gbc", "gb": self = .gbc
        case "gba": self = .gba
        case "ds", "nds": self = .ds
        default: return nil
        }
    }
}
