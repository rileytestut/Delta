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
    // Alternatively, this feature could be implemented with single hidden dictionary @Option mapping preferred speeds to systems,
    // because we support changing these values by long-pressing the Fast Forward button in the pause menu.
    // However, we want to also show these options in Delta's settings, which requires us to explicitly define them one-by-one.
    //
    // @Option // No name = hidden
    // var preferredSpeedsBySystem: [String: Double] = [:]
    
    @Option(name: "Nintendo", description: "Preferred NES fast forward speed.", values: FastForwardSpeed.allCases)
    var nes: FastForwardSpeed?

    @Option(name: "Super Nintendo", description: "Preferred SNES fast forward speed.", values: FastForwardSpeed.allCases)
    var snes: FastForwardSpeed?
    
    @Option(name: "Sega Genesis", description: "Preferred Genesis fast forward speed.", values: FastForwardSpeed.allCases)
    var genesis: FastForwardSpeed?

    @Option(name: "Nintendo 64", description: "Preferred N64 fast forward speed.", values: FastForwardSpeed.allCases)
    var n64: FastForwardSpeed?

    @Option(name: "Game Boy Color", description: "Preferred GBC fast forward speed.", values: FastForwardSpeed.allCases)
    var gbc: FastForwardSpeed?

    @Option(name: "Game Boy Advance", description: "Preferred GBA fast forward speed.", values: FastForwardSpeed.allCases)
    var gba: FastForwardSpeed?

    @Option(name: "Nintendo DS", description: "Preferred DS fast forward speed.", values: FastForwardSpeed.allCases)
    var ds: FastForwardSpeed?
}
