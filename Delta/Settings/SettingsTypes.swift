//
//  SettingsTypes.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

extension Notification.Name
{
    static let settingsDidChange = Notification.Name("SettingsDidChangeNotification")
}

extension Settings
{
    enum NotificationUserInfoKey: String
    {
        case name
        
        case system
        case traits
        
        case core
    }
    
    enum Name: String
    {
        case localControllerPlayerIndex
        case translucentControllerSkinOpacity
        case preferredControllerSkin
        case syncingService
        case isButtonHapticFeedbackEnabled
        case isThumbstickHapticFeedbackEnabled
        case isAltJITEnabled
        case respectSilentMode
    }
}

struct Settings
{
}
