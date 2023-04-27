//
//  VariableFastForward.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import DeltaFeatures

struct FastForwardSpeed: RawRepresentable
{
    let rawValue: Double
    
    init(rawValue: Double)
    {
        self.rawValue = rawValue
    }
    
    static func speeds(in range: ClosedRange<Double>) -> [FastForwardSpeed]
    {
        var range = range
        
        if ExperimentalFeatures.shared.variableFastForward.allowUnrestrictedSpeeds
        {
            range = 1.0...8.0
        }
        
        // .dropFirst() to remove 1x speed.
        var speeds = stride(from: range.lowerBound, to: range.upperBound, by: 1.0).dropFirst().map { FastForwardSpeed(rawValue: $0) }
        
        // Handles both integer and non-integer maximum speeds, because range.upperBound is not included in `speeds`.
        speeds.append(.init(rawValue: range.upperBound))
        
        return speeds
    }
}

extension FastForwardSpeed: CustomStringConvertible, LocalizedOptionValue
{
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
    
    @Option(name: "Nintendo", description: "Preferred NES fast forward speed.", values: FastForwardSpeed.speeds(in: System.nes.deltaCore.supportedRates))
    var nes: FastForwardSpeed?

    @Option(name: "Super Nintendo", description: "Preferred SNES fast forward speed.", values: FastForwardSpeed.speeds(in: System.snes.deltaCore.supportedRates))
    var snes: FastForwardSpeed?
    
    @Option(name: "Sega Genesis", description: "Preferred Genesis fast forward speed.", values: FastForwardSpeed.speeds(in: System.genesis.deltaCore.supportedRates))
    var genesis: FastForwardSpeed?

    @Option(name: "Nintendo 64", description: "Preferred N64 fast forward speed.", values: FastForwardSpeed.speeds(in: System.n64.deltaCore.supportedRates))
    var n64: FastForwardSpeed?

    @Option(name: "Game Boy Color", description: "Preferred GBC fast forward speed.", values: FastForwardSpeed.speeds(in: System.gbc.deltaCore.supportedRates))
    var gbc: FastForwardSpeed?

    @Option(name: "Game Boy Advance", description: "Preferred GBA fast forward speed.", values: FastForwardSpeed.speeds(in: System.gba.deltaCore.supportedRates))
    var gba: FastForwardSpeed?

    @Option(name: "Nintendo DS", description: "Preferred DS fast forward speed.", values: FastForwardSpeed.speeds(in: System.ds.deltaCore.supportedRates))
    var ds: FastForwardSpeed?
    
    @Option(name: "Allow Unrestricted Speeds", description: "Allow choosing speeds that exceed the maximum supported speed of a system.\n\nThis can be used to test the performance of new iOS devices.")
    var allowUnrestrictedSpeeds: Bool = false
}

extension Feature where Options == VariableFastForwardOptions
{
    subscript(gameType: GameType) -> FastForwardSpeed? {
        get {
            guard let system = System(gameType: gameType) else { return nil }
            switch system
            {
            case .nes: return self.nes
            case .snes: return self.snes
            case .genesis: return self.genesis
            case .n64: return self.n64
            case .gbc: return self.gbc
            case .gba: return self.gba
            case .ds: return self.ds
            }
        }
        set {
            guard let system = System(gameType: gameType) else { return }
            switch system
            {
            case .nes: self.nes = newValue
            case .snes: self.snes = newValue
            case .genesis: self.genesis = newValue
            case .n64: self.n64 = newValue
            case .gbc: self.gbc = newValue
            case .gba: self.gba = newValue
            case .ds: self.ds = newValue
            }
        }
    }
}
