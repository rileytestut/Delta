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

enum System: CaseIterable
{
    case nes
    case snes
    case gbc
    case gba
}

extension System
{
    var localizedName: String {
        switch self
        {
        case .nes: return NSLocalizedString("Nintendo", comment: "")
        case .snes: return NSLocalizedString("Super Nintendo", comment: "")
        case .gbc: return NSLocalizedString("Game Boy Color", comment: "")
        case .gba: return NSLocalizedString("Game Boy Advance", comment: "")
        }
    }
    
    var localizedShortName: String {
        switch self
        {
        case .nes: return NSLocalizedString("NES", comment: "")
        case .snes: return NSLocalizedString("SNES", comment: "")
        case .gbc: return NSLocalizedString("GBC", comment: "")
        case .gba: return NSLocalizedString("GBA", comment: "")
        }
    }
    
    var year: Int {
        switch self
        {
        case .nes: return 1985
        case .snes: return 1990
        case .gbc: return 1998
        case .gba: return 2001
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
        case .gbc: return GBC.core
        case .gba: return GBA.core
        }
    }
    
    var gameType: GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
        case .gbc: return .gbc
        case .gba: return .gba
        }
    }
    
    init?(gameType: GameType)
    {
        switch gameType
        {
        case GameType.nes: self = .nes
        case GameType.snes: self = .snes
        case GameType.gbc: self = .gbc
        case GameType.gba: self = .gba
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
        case "gbc", "gb": self = .gbc
        case "gba": self = .gba
        default: return nil
        }
    }
}
