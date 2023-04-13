//
//  Feature.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

@propertyWrapper @dynamicMemberLookup
public final class Feature
{
    public let name: LocalizedStringKey
    public let description: LocalizedStringKey?
    
    // Assigned to property name.
    public internal(set) var key: String = ""
    
    // Used for `SettingsUserInfoKey.name` value in .settingsDidChange notification.
    public var settingsKey: SettingsName {
        return SettingsName(rawValue: self.key)
    }
    
    public var isEnabled: Bool {
        get {
            let isEnabled = UserDefaults.standard.bool(forKey: self.key)
            return isEnabled
        }
        set {
            self.objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: self.key)
            
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [SettingsUserInfoKey.name: self.settingsKey, SettingsUserInfoKey.value: newValue])
        }
    }
    
    public var wrappedValue: Feature {
        return self
    }
    
    public init(name: LocalizedStringKey, description: LocalizedStringKey? = nil)
    {
        self.name = name
        self.description = description
    }
}
