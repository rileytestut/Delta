//
//  GameType+Localization.swift
//  Delta
//
//  Created by Riley Testut on 10/3/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import DeltaCore

extension GameType
{
    var localizedName: String
    {
        switch self
        {
        case GameType.snes: return NSLocalizedString("Super Nintendo Entertainment System", comment: "")
        case GameType.gba: return NSLocalizedString("Game Boy Advance", comment: "")
        case GameType.delta: return NSLocalizedString("Unsupported System", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
    
    var localizedShortName: String
    {
        switch self
        {
        case GameType.snes: return NSLocalizedString("SNES", comment: "")
        case GameType.gba: return NSLocalizedString("GBA", comment: "")
        case GameType.delta: return NSLocalizedString("Unsupported", comment: "")
        default: return NSLocalizedString("Unknown", comment: "")
        }
    }
}
