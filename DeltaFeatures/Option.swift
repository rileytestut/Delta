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
public class Option<Value: OptionValue, DetailView: View>: _AnyOption
{
    // Nil name == hidden option.
    public let name: LocalizedStringKey?
    public let description: LocalizedStringKey?
    
    public private(set) var detailView: () -> DetailView? = { nil }
    
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
    
    private var valueBinding: Binding<Value> {
        Binding(get: {
            self.wrappedValue
        }, set: { newValue in
            self.wrappedValue = newValue
        })
    }
    
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
    
    private init(defaultValue: Value, name: LocalizedStringKey?, description: LocalizedStringKey?)
    {
        self.defaultValue = defaultValue
        
        self.name = name
        self.description = description
        self.detailView = { nil }
    }
}

// "Hidden" Option (no name or custom SwiftUI view)
public extension Option where DetailView == EmptyView
{
    // Non-Optional
    convenience init(wrappedValue: Value)
    {
        self.init(defaultValue: wrappedValue, name: nil, description: nil)
    }
    
    // Optional, default = nil
    convenience init() where Value: OptionalProtocol
    {
        self.init(defaultValue: Value.none, name: nil, description: nil)
    }
    
    // Optional, default = non-nil
    convenience init(wrappedValue: Value) where Value: OptionalProtocol
    {
        self.init(defaultValue: wrappedValue, name: nil, description: nil)

// "Custom" Option (User-visible, provides SwiftUI view to configure option)
public extension Option where Value: LocalizedOptionValue
{
    // Non-Optional
    convenience init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder detailView: @escaping (Binding<Value>) -> DetailView)
    {
        self.init(defaultValue: wrappedValue, name: name, description: description)
        
        self.detailView = { [weak self] in
            guard let self else { return nil }
            
            let view = detailView(self.valueBinding)
            return view
        }
    }
    
    // Optional, default = nil
    convenience init(name: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder detailView: @escaping (Binding<Value>) -> DetailView) where Value: OptionalProtocol, Value.Wrapped: LocalizedOptionValue
    {
        self.init(defaultValue: Value.none, name: name, description: description)
        
        self.detailView = { [weak self] in
            guard let self else { return nil }
            
            let view = detailView(self.valueBinding)
            return view
        }
    }
    
    // Optional, default = non-nil
    convenience init(wrappedValue: Value, name: LocalizedStringKey, description: LocalizedStringKey? = nil, @ViewBuilder detailView: @escaping (Binding<Value>) -> DetailView) where Value: OptionalProtocol, Value.Wrapped: LocalizedOptionValue
    {
        self.init(defaultValue: wrappedValue, name: name, description: description)
        
        self.detailView = { [weak self] in
            guard let self else { return nil }
            
            let view = detailView(self.valueBinding)
            return view
        }
    }
}
