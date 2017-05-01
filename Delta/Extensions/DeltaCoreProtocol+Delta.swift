//
//  DeltaCoreProtocol+Delta.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore
import GBADeltaCore

extension DeltaCoreProtocol
{
    var supportedRates: ClosedRange<Double> {
        switch self.gameType
        {
        case GameType.gba: return 1...3
        default: return 1...4
        }
    }
}
