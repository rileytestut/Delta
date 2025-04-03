//
//  AchievementsError.swift
//  Delta
//
//  Created by Riley Testut on 3/6/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation

struct AchievementsError: CustomNSError
{
    // Use positive values for our own error codes
    static let notAuthenticated: Int = 1
    static let unsupportedSystem: Int = 2
    
    static var errorDomain: String { "AchievementsError" }
    
    var errorCode: Int
    var message: String?
    
    var errorUserInfo: [String : Any] {
        let localizedDescription: String = if let message {
            String(format: NSLocalizedString("Error %@. %@", comment: ""), NSNumber(value: self.errorCode), message)
        } else {
            String(format: NSLocalizedString("Error %@", comment: ""), NSNumber(value: self.errorCode))
        }
        
        return [NSLocalizedDescriptionKey: localizedDescription]
    }
}
