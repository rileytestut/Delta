import Foundation
import DeltaCore
import NESDeltaCore
import SNESDeltaCore
import N64DeltaCore

enum TVSystem: String, CaseIterable, Identifiable {
    case nes = "NES"
    case snes = "SNES"
    case n64 = "N64"
    
    var id: String { rawValue }
    
    var fullName: String {
        switch self {
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .n64: return "Nintendo 64"
        }
    }
    
    var shortName: String {
        return rawValue
    }
    
    var gameType: GameType {
        switch self {
        case .nes: return NES.core.gameType
        case .snes: return SNES.core.gameType
        case .n64: return N64.core.gameType
        }
    }
    
    var supportedExtensions: [String] {
        switch self {
        case .nes: return ["nes"]
        case .snes: return ["smc", "sfc", "fig"]
        case .n64: return ["n64", "z64", "v64"]
        }
    }
    
    var systemIconName: String {
        switch self {
        case .nes: return "dpad"
        case .snes: return "gamecontroller"
        case .n64: return "arcade.stick.console"
        }
    }
}
