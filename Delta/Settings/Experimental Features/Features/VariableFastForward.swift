//
//  VariableFastForward.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import SwiftUI

enum FastForwardSpeed: Double, CaseIterable, Identifiable, CustomStringConvertible
{
    case x2 = 2
    case x3 = 3
    case x4 = 4
    case x8 = 8

    var id: Self { self }

    var description: String {
        return "\(self.rawValue)x"
    }
}

extension FastForwardSpeed: LocalizedOptionValue
{
    var localizedDescription: Text {
        return Text(self.description)
    }
}

class VariableFastForwardOptions: ObservableObject
{
//    @Option(name: "Speed", values: FastForwardSpeed.allCases)
//    var value: FastForwardSpeed? = nil
    
    @Option // Type must be ObjC Plist compatible (with auto-conversations)
    var preferredSpeedsBySystem: [String: Double] = [:]
    
    @Option(name: "NES", description: "Speed of NES system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.nes.deltaCore.supportedRates.upperBound })
    var nes: FastForwardSpeed?
    
    @Option(name: "SNES", description: "Speed of SNES system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.snes.deltaCore.supportedRates.upperBound })
    var snes: FastForwardSpeed?
    
    @Option(name: "Nintendo 64", description: "Speed of N64 system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.n64.deltaCore.supportedRates.upperBound })
    var n64: FastForwardSpeed?
    
    @Option(name: "Game Boy Color", description: "Speed of Game Boy Color system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.gbc.deltaCore.supportedRates.upperBound })
    var gbc: FastForwardSpeed?
    
    @Option(name: "Game Boy Advance", description: "Speed of Game Boy Advance system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.gba.deltaCore.supportedRates.upperBound })
    var gba: FastForwardSpeed?
    
    @Option(name: "Nintendo DS", description: "Speed of Nintendo DS system.", values: FastForwardSpeed.allCases.filter { $0.rawValue <= 4 })// System.ds.deltaCore.supportedRates.upperBound })
    var ds: FastForwardSpeed?
}
