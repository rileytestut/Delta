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
