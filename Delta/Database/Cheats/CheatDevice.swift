//
//  CheatDevice.swift
//  Delta
//
//  Created by Riley Testut on 1/30/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import NESDeltaCore

@objc
enum CheatDevice: Int16
{
    case famicomGameGenie = 1
    case famicomRaw = 2
    case famicomRawCompare = 3
    
    case gbGameGenie = 4
    
    case gbaActionReplayMax = 5
    case gbaCodeBreaker = 6
    case gbaGameShark = 7
    
    case gbcGameShark = 8
    
    case n64GameShark = 9
    
    case dsActionReplay = 10
    case dsCodeBreaker = 11
    
    case nesGameGenie = 12
    case nesRaw = 13
    case nesRawCompare = 14
    
    case snesActionReplay = 15
    case snesGameGenie = 16
    
    case gameGearActionReplay = 17
    case gameGearGameGenie = 18
    
    case masterSystemActionReplay = 19
    case masterSystemGameGenie = 20
    
    case cdActionReplay10 = 21
    case cdActionReplay8 = 22
    
    case genesisActionReplay10 = 23
    case genesisActionReplay8 = 24
}

extension CheatDevice
{
    var cheatType: CheatType? {
        switch self
        {
        case .snesActionReplay, .gbaActionReplayMax, .dsActionReplay, .gameGearActionReplay, .masterSystemActionReplay, .genesisActionReplay8, .genesisActionReplay10, .cdActionReplay8, .cdActionReplay10:
            return .actionReplay
            
        case .n64GameShark, .gbcGameShark, .gbaGameShark:
            return .gameShark
            
        case .famicomGameGenie, .snesGameGenie, .gbGameGenie, .gameGearGameGenie, .masterSystemGameGenie:
            return .gameGenie
            
        case .nesGameGenie:
            return CheatType(rawValue: DeltaCore.CheatType.gameGenie8.rawValue)
            
        case .gbaCodeBreaker, .dsCodeBreaker:
            return .codeBreaker
            
        case .famicomRaw, .famicomRawCompare:
            return nil
            
        case .nesRaw, .nesRawCompare:
            return nil
        }
    }
    
    var gameType: GameType? {
        switch self
        {
        case .famicomGameGenie, .famicomRaw, .famicomRawCompare: return .nes
        case .nesGameGenie, .nesRaw, .nesRawCompare: return .nes
        case .snesActionReplay, .snesGameGenie: return .snes
        case .n64GameShark: return .n64
        case .gbGameGenie, .gbcGameShark: return .gbc
        case .gbaActionReplayMax, .gbaGameShark, .gbaCodeBreaker: return .gba
        case .dsActionReplay, .dsCodeBreaker: return .ds
        case .genesisActionReplay8, .genesisActionReplay10: return .genesis
        case .cdActionReplay8, .cdActionReplay10: return .genesis
            
        // Not yet supported
        case .gameGearActionReplay, .gameGearGameGenie: return nil
        case .masterSystemActionReplay, .masterSystemGameGenie: return nil
        }
    }
    
    var cheatFormat: CheatFormat? {
        guard
            let cheatType = self.cheatType,
            let gameType = self.gameType,
            let deltaCore = Delta.core(for: gameType)
        else { return nil }
        
        let cheatFormat = deltaCore.supportedCheatFormats.first { $0.type == cheatType }
        return cheatFormat
    }
}
