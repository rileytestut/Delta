import DeltaCore
import NESDeltaCore
import SNESDeltaCore
import N64DeltaCore
import GBCDeltaCore
import GBADeltaCore
import GPGXDeltaCore
import MelonDSDeltaCore

extension TVSystem {
    var gameType: GameType { core.gameType }

    var core: DeltaCoreProtocol {
        switch self {
        case .nes: return NES.core
        case .snes: return SNES.core
        case .n64: return N64.core
        case .gbc: return GBC.core
        case .gba: return GBA.core
        case .genesis: return GPGX.core
        case .ds: return MelonDS.core
        }
    }
}
