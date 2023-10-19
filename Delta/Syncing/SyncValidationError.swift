//
//  SyncValidationError.swift
//  Delta
//
//  Created by Riley Testut on 8/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

enum SyncValidationError: LocalizedError
{
    case incorrectGame(String?)
    case incorrectGameCollection(String?)
    
    var failureReason: String? {
        switch self
        {
        case .incorrectGame(let name?):
            return String(format: NSLocalizedString("The downloaded record is associated with the wrong game (%@).", comment: ""), name)
        
        case .incorrectGame(nil):
            return NSLocalizedString("The downloaded record is not associated with a game.", comment: "")
            
        case .incorrectGameCollection(let name?):
            return String(format: NSLocalizedString("The downloaded record is associated with the wrong game system (%@).", comment: ""), name)
            
        case .incorrectGameCollection(nil):
            return NSLocalizedString("The downloaded record is not associated with a game system.", comment: "")
        }
    }
    
    var recoverySuggestion: String? {
        switch self
        {
        case .incorrectGame: return NSLocalizedString("Try restoring an older version to resolve this issue.", comment: "")
        case .incorrectGameCollection: return NSLocalizedString("Try restoring an older version, or manually re-import the game to resolve this issue.", comment: "")
        }
    }
}
