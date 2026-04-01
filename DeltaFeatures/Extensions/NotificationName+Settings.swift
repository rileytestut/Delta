//
//  Notification+Settings.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/13/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public extension Notification.Name
{
    static let settingsDidChange = Notification.Name("SettingsDidChangeNotification")
    static let settingsDidClose  = Notification.Name("SettingsDidCloseNotification")
}
