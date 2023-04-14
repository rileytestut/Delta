//
//  Option.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

@propertyWrapper
public class Option<Value: OptionValue>: _AnyOption
{
    // Assigned to property name.
    public internal(set) var key: String = ""
    
    // Used for `SettingsUserInfoKey.name` value in .settingsDidChange notification.
    public var settingsKey: SettingsName {
        guard let feature = self.feature else { return SettingsName(rawValue: self.key) }
        
        let defaultsKey = feature.key + "_" + self.key
        return SettingsName(rawValue: defaultsKey)
    }
    
    internal weak var feature: (any AnyFeature)?
    
    private let defaultValue: Value
    
    /// @propertyWrapper
    public var projectedValue: some Option {
        return self
    }
    
    public var wrappedValue: Value {
        get {
            do {
                let wrappedValue = try UserDefaults.standard.optionValue(forKey: self.settingsKey.rawValue, type: Value.self)
                return wrappedValue ?? self.defaultValue
            }
            catch {
                print("[ALTLog] Failed to read option value for key \(self.settingsKey.rawValue).", error)
                return self.defaultValue
            }
        }
        set {
            Task { @MainActor in
                // Delay to avoid "Publishing changes from within view updates is not allowed" runtime warning.
                (self.feature?.objectWillChange as? ObservableObjectPublisher)?.send()
            }
            
            do {
                try UserDefaults.standard.setOptionValue(newValue, forKey: self.settingsKey.rawValue)
                NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [SettingsUserInfoKey.name: self.settingsKey, SettingsUserInfoKey.value: newValue])
            }
            catch {
                print("[ALTLog] Failed to set option value for key \(self.settingsKey.rawValue).", error)
            }
        }
    }
    
    // Non-Optional
    public init(wrappedValue: Value)
    {
        self.defaultValue = wrappedValue
    }
    
    // Optional, default = nil
    public init() where Value: OptionalProtocol
    {
        self.defaultValue = Value.none
    }
    
    // Optional, default = non-nil
    public init(wrappedValue: Value) where Value: OptionalProtocol
    {
        self.defaultValue = wrappedValue
    }
}
