//
//  DeltaCoreProtocol+Delta.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

import NESDeltaCore
import SNESDeltaCore
import GBCDeltaCore
import GBADeltaCore
import N64DeltaCore
import MelonDSDeltaCore
import GPGXDeltaCore

extension Delta
{
    // Legacy Cores
    static let desmumeCoreID = "com.rileytestut.DSDeltaCore"
}

@dynamicMemberLookup
struct DeltaCoreMetadata
{
    enum Key: String, CaseIterable
    {
        case name
        case developer
        case version
        case source
        case donate
        
        var localizedName: String {
            return self.rawValue.capitalized
        }
    }
    
    struct Item
    {
        var value: String
        var url: URL?
    }
    
    var name: Item { self.items[.name]! }
    private let items: [Key: Item]
    
    init?(_ items: [Key: Item])
    {
        guard items.keys.contains(.name) else { return nil }
        self.items = items
    }
    
    subscript(dynamicMember keyPath: KeyPath<Key.Type, Key>) -> Item?
    {
        let key = Key.self[keyPath: keyPath]
        return self[key]
    }
    
    subscript(_ key: Key) -> Item?
    {
        let item = self.items[key]
        return item
    }
}

extension DeltaCoreProtocol
{
    var supportedRates: ClosedRange<Double> {
        return 1...self.maximumFastForwardSpeed
    }
    
    private var maximumFastForwardSpeed: Double {
        switch self
        {
        case NES.core, SNES.core, GBC.core: return 4
        case GBA.core: return 3
        case N64.core where UIDevice.current.hasA11ProcessorOrBetter: return 3
        case N64.core where UIDevice.current.hasA9ProcessorOrBetter: return 1.5
        case MelonDS.core where UIDevice.current.hasA15ProcessorOrBetter || ProcessInfo.processInfo.isJITAvailable: return 3
        case MelonDS.core where UIDevice.current.hasA11ProcessorOrBetter: return 1.5
        case GPGX.core: return 4
        default: return 1
        }
    }
    
    var metadata: DeltaCoreMetadata? {
        switch self
        {
        case MelonDS.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("melonDS", comment: ""), url: URL(string: "http://melonds.kuribo64.net")),
                                      .developer: .init(value: NSLocalizedString("Arisotura", comment: ""), url: URL(string: "https://twitter.com/Arisotura")),
                                      .version: .init(value: NSLocalizedString("0.9.5", comment: ""), url: URL(string: "https://github.com/melonDS-emu/melonDS/releases/tag/0.9.5")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/Arisotura/melonDS")),
                                      .donate: .init(value: NSLocalizedString("Patreon", comment: ""), url: URL(string: "https://www.patreon.com/staplebutter"))])
        case GBC.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("Gambatte", comment: "")),
                                      .developer: .init(value: NSLocalizedString("sinamas", comment: ""), url: URL(string: "https://github.com/sinamas")),
                                      .version: .init(value: NSLocalizedString("r571", comment: ""), url: URL(string: "https://sourceforge.net/projects/gambatte/files/gambatte/r571/")),
                                      .source: .init(value: NSLocalizedString("SourceForge", comment: ""), url: URL(string: "https://sourceforge.net/projects/gambatte/"))])
        case NES.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("Nestopia", comment: ""), url: URL(string: "https://nestopia.sourceforge.net")),
                                      .developer: .init(value: NSLocalizedString("Martin Freij", comment: "")),
                                      .version: .init(value: NSLocalizedString("1.40", comment: "")),
                                      .source: .init(value: NSLocalizedString("SourceForge", comment: ""), url: URL(string: "https://sourceforge.net/projects/nestopia/files/"))])
        case SNES.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("Snes9x", comment: ""), url: URL(string: "https://www.snes9x.com")),
                                      .developer: .init(value: NSLocalizedString("Snes9x Team", comment: "")),
                                      .version: .init(value: NSLocalizedString("1.63", comment: ""), url: URL(string: "https://github.com/snes9xgit/snes9x/releases/tag/1.63")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/snes9xgit/snes9x"))])
        case GBA.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("VisualBoyAdvance-M", comment: ""), url: URL(string: "https://visualboyadvance-m.org")),
                                      .developer: .init(value: NSLocalizedString("VBA-M Team", comment: "")),
                                      .version: .init(value: NSLocalizedString("2.2.2", comment: ""), url: URL(string: "https://github.com/visualboyadvance-m/visualboyadvance-m/releases/tag/v2.2.2")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/visualboyadvance-m/visualboyadvance-m"))])
        case N64.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("Mupen64Plus", comment: ""), url: URL(string: "https://mupen64plus.org")),
                                      .developer: .init(value: NSLocalizedString("Richard Goedeken", comment: ""), url: URL(string: "https://github.com/richard42")),
                                      .version: .init(value: NSLocalizedString("2.6.0", comment: ""), url: URL(string: "https://github.com/mupen64plus/mupen64plus-core/releases/tag/2.6.0")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/mupen64plus/mupen64plus-core"))])
        case GPGX.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("Genesis Plus GX", comment: "")),
                                      .developer: .init(value: NSLocalizedString("eke-eke", comment: ""), url: URL(string: "https://github.com/ekeeke")),
                                      .version: .init(value: NSLocalizedString("1.7.4", comment: "")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/ekeeke/Genesis-Plus-GX"))])
        case PS1.core:
            return DeltaCoreMetadata([.name: .init(value: "PCSX ReARMed (libretro)", url: URL(string: "https://github.com/libretro/pcsx_rearmed")),
                                      .developer: .init(value: "PCSX Team, notaz, Exophase", url: URL(string: "https://github.com/libretro/pcsx_rearmed/blob/master/AUTHORS")),
                                      .version: .init(value: "r26"),
                                      .source: .init(value: "libretro GitHub", url: URL(string: "https://github.com/libretro/pcsx_rearmed"))])
        default: return nil
        }
    }
}
