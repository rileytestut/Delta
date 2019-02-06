//
//  DeltaCoreProtocol+Delta.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

extension DeltaCoreProtocol
{
    var supportedRates: ClosedRange<Double> {
        guard let system = System(gameType: self.gameType) else { return 1...1 }
        
        switch system
        {
        case .nes: return 1...4
        case .snes: return 1...4
        case .gbc: return 1...4
        case .gba: return 1...3
        }
    }
}
