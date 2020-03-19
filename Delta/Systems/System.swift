//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

import SNESDeltaCore
import GBADeltaCore
import GBCDeltaCore
import NESDeltaCore
import N64DeltaCore
import MelonDSDeltaCore

enum System: CaseIterable
{
    case nes
    case snes
    case n64
    case gbc
    case gba
    case ds
    
    static var registeredSystems: [System] {
        let systems = System.allCases.filter { Delta.registeredCores.keys.contains($0.gameType) }
        return systems
    }
}

extension System
{
    var localizedName: String {
        switch self
        {
        case .nes: return NSLocalizedString("Nintendo", comment: "")
        case .snes: return NSLocalizedString("Super Nintendo", comment: "")
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
}

extension System
{
    var deltaCore: DeltaCoreProtocol {
        switch self
        {
        case .nes: return NES.core
        case .snes: return SNES.core
        case .n64: return N64.core
        case .gbc: return GBC.core
        case .gba: return GBA.core
        case .ds: return MelonDS.core
        }
    }
    
    var gameType: GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
        case .n64: return .n64
        case .gbc: return .gbc
        case .gba: return .gba
        case .ds: return .melonDS
        }
    }
    
    init?(gameType: GameType)
    {
        switch gameType
        {
        case GameType.nes: self = .nes
        case GameType.snes: self = .snes
        case GameType.n64: self = .n64
        case GameType.gbc: self = .gbc
        case GameType.gba: self = .gba
//        case GameType.ds: self = .ds
        case GameType.melonDS: self = .ds
        default: return nil
        }
    }
}

extension GameType
{
    init?(fileExtension: String)
    {
        switch fileExtension.lowercased()
        {
        case "nes": self = .nes
        case "smc", "sfc", "fig": self = .snes
        case "n64", "z64": self = .n64
        case "gbc", "gb": self = .gbc
        case "gba": self = .gba
        case "ds", "nds": self = .melonDS
        default: return nil
        }
    }
}
