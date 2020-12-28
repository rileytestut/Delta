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
import Mupen64PlusDeltaCore
import MelonDSDeltaCore

// Legacy Cores
import struct DeSmuMEDeltaCore.DeSmuME

@dynamicMemberLookup
struct DeltaCoreMetadata
{
    enum Key: CaseIterable
    {
        case name
        case developer
        case source
        case donate
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
        switch self
        {
        case NES.core: return 1...4
        case SNES.core: return 1...4
        case GBC.core: return 1...4
        case GBA.core: return 1...3
        case Mupen64Plus.core: return 1...3
        case DeSmuME.core: return 1...3
        case MelonDS.core: return 1...2
        default: return 1...2
        }
    }
    
    var metadata: DeltaCoreMetadata? {
        switch self
        {
        case DeSmuME.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("DeSmuME (Legacy)", comment: ""), url: URL(string: "http://desmume.org")),
                                      .developer: .init(value: NSLocalizedString("DeSmuME team", comment: ""), url: URL(string: "https://wiki.desmume.org/index.php?title=DeSmuME:About")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/TASVideos/desmume"))])
            
        case MelonDS.core:
            return DeltaCoreMetadata([.name: .init(value: NSLocalizedString("melonDS", comment: ""), url: URL(string: "http://melonds.kuribo64.net")),
                                      .developer: .init(value: NSLocalizedString("Arisotura", comment: ""), url: URL(string: "https://twitter.com/Arisotura")),
                                      .source: .init(value: NSLocalizedString("GitHub", comment: ""), url: URL(string: "https://github.com/Arisotura/melonDS")),
                                      .donate: .init(value: NSLocalizedString("Patreon", comment: ""), url: URL(string: "https://www.patreon.com/staplebutter"))])
            
        default: return nil
        }
    }
}
