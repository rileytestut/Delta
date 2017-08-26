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
import NDSDeltaCore

extension GameType
{
    init?(fileExtension: String)
    {
        switch fileExtension.lowercased()
        {
        case "smc", "sfc", "fig": self = .snes
        case "gba": self = .gba
        case "gbc", "gb": self = .gbc
        case "nds": self = .nds
        default: return nil
        }
    }
}

enum System
{
    case snes
    case gba
    case gbc
    case nds
    
    static var supportedSystems: [System] {
        return [.snes, .gba, .gbc, .nds]
    }
}

extension System
{
    var localizedName: String {
        switch self
        {
        case .snes: return NSLocalizedString("Super Nintendo", comment: "")
        case .gba: return NSLocalizedString("Game Boy Advance", comment: "")
        case .gbc: return NSLocalizedString("Game Boy Color", comment: "")
        case .nds: return NSLocalizedString("Nintendo DS", comment: "")
        }
    }
    
    var localizedShortName: String {
        switch self
        {
        case .snes: return NSLocalizedString("SNES", comment: "")
        case .gba: return NSLocalizedString("GBA", comment: "")
        case .gbc: return NSLocalizedString("GBC", comment: "")
        case .nds: return NSLocalizedString("NDS", comment: "")
        }
    }
    
    var year: Int {
        switch self
        {
        case .snes: return 1990
        case .gba: return 2001
        case .gbc: return 1998
        case .nds: return 2004
        }
    }
}

extension System
{
    var deltaCore: DeltaCoreProtocol {
        switch self
        {
        case .snes: return SNES.core
        case .gba: return GBA.core
        case .gbc: return GBC.core
        case .nds: return NDS.core
        }
    }
}

extension System
{
    var gameType: GameType {
        switch self
        {
        case .snes: return .snes
        case .gba: return .gba
        case .gbc: return .gbc
        case .nds: return .nds
        }
    }
    
    init?(gameType: GameType)
    {
        switch gameType
        {
        case GameType.snes: self = .snes
        case GameType.gba: self = .gba
        case GameType.gbc: self = .gbc
        case GameType.nds: self = .nds
        default: return nil
        }
    }
}
