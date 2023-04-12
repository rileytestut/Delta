//
//  SettingsTypes.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public extension Notification.Name
{
    static let settingsDidChange = Notification.Name("SettingsDidChangeNotification")
}

public extension Settings
{
    struct NotificationUserInfoKey: RawRepresentable, Hashable, ExpressibleByStringLiteral
    {
        public static let name: NotificationUserInfoKey = "name"
        public static let system: NotificationUserInfoKey = "system"
        public static let traits: NotificationUserInfoKey = "traits"
        public static let core: NotificationUserInfoKey = "core"
        
        public static let value: NotificationUserInfoKey = "value"
        
        public let rawValue: String
        
        public init(rawValue: String)
        {
            self.rawValue = rawValue
        }

        public init(stringLiteral rawValue: String)
        {
            self.rawValue = rawValue
        }
    }
    
    struct Name: RawRepresentable, Hashable, ExpressibleByStringLiteral
    {
        public static let localControllerPlayerIndex: Name = "localControllerPlayerIndex"
        public static let translucentControllerSkinOpacity: Name = "translucentControllerSkinOpacity"
        public static let preferredControllerSkin: Name = "preferredControllerSkin"
        public static let syncingService: Name = "syncingService"
        public static let isButtonHapticFeedbackEnabled: Name = "isButtonHapticFeedbackEnabled"
        public static let isThumbstickHapticFeedbackEnabled: Name = "isThumbstickHapticFeedbackEnabled"
        public static let isAltJITEnabled: Name = "isAltJITEnabled"
        public static let respectSilentMode: Name = "respectSilentMode"
        
        public let rawValue: String
        
        public init(rawValue: String)
        {
            self.rawValue = rawValue
        }
        
        public init(stringLiteral rawValue: String)
        {
            self.rawValue = rawValue
        }
    }
}

public struct Settings
{
}
