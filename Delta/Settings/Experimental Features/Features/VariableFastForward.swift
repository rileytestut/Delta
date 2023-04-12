//
//  VariableFastForward.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum FastForwardSpeed: Double, CaseIterable, CustomStringConvertible
{
    case x2 = 2
    case x3 = 3
    case x4 = 4
    case x8 = 8
    
    var description: String {
        if #available(iOS 15, *)
        {
            let formattedText = self.rawValue.formatted(.number.decimalSeparator(strategy: .automatic))
            return "\(formattedText)x"
        }
        else
        {
            return "\(self.rawValue)x"
        }
    }
}

extension FastForwardSpeed: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
    
    static var localizedNilDescription: Text {
        Text("Maximum")
    }
}

struct VariableFastForwardOptions
{
    @Option // No name = hidden
    var preferredSpeedsBySystem: [String: Double] = [:] // Type must be ObjC Plist compatible (with auto-bridging).
    
    @Option(name: "NES", description: "Preferred Nintendo Entertainment System speed.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.nes.deltaCore.supportedRates.upperBound })
    var nes: FastForwardSpeed?
    
    @Option(name: "SNES", description: "Preferred Super Nintendo speed.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.snes.deltaCore.supportedRates.upperBound })
    var snes: FastForwardSpeed?
    
    @Option(name: "Nintendo 64", description: "Preferred Nintendo 64 speed.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.n64.deltaCore.supportedRates.upperBound })
    var n64: FastForwardSpeed?
    
    @Option(name: "Game Boy Color", description: "Speed of Game Boy Color system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.gbc.deltaCore.supportedRates.upperBound })
    var gbc: FastForwardSpeed?
    
    @Option(name: "Game Boy Advance", description: "Speed of Game Boy Advance system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.gba.deltaCore.supportedRates.upperBound })
    var gba: FastForwardSpeed?
    
    @Option(name: "Nintendo DS", description: "Speed of Nintendo DS system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.ds.deltaCore.supportedRates.upperBound })
    var ds: FastForwardSpeed?
    
    @Option(name: "Genesis", description: "Preferred Sega Genesis speed.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.ds.deltaCore.supportedRates.upperBound })
    var genesis: FastForwardSpeed?
}
