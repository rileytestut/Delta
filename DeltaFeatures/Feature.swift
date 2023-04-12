//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

public class AnyFeature: ObservableObject
{
    public let name: LocalizedStringKey
    public let description: LocalizedStringKey?
    
    // Assigned to property name.
    public internal(set) var key: String = ""
    
    // Used for `NotificationUserInfoKey.name` value in .settingsDidChange notification.
    public var settingsKey: Settings.Name {
        return Settings.Name(rawValue: self.key)
    }
    
    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: self.key) }
        set {
            self.objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: self.key)
            
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [Settings.NotificationUserInfoKey.name: self.settingsKey, Settings.NotificationUserInfoKey.value: newValue])
        }
    }
    
    fileprivate init(name: LocalizedStringKey, description: LocalizedStringKey? = nil)
    {
        self.name = name
        self.description = description
    }
    
    // Overridden
    public var allOptions: [any AnyOption] { [] }
}

extension AnyFeature: Identifiable
{
    public var id: String { self.key }
}

extension AnyFeature
{
    public struct EmptyOptions {}
}

@propertyWrapper @dynamicMemberLookup
public final class Feature<Options>: AnyFeature
{
    private var options: Options
    
    public var wrappedValue: some Feature {
        return self
    }
    
    public init(name: LocalizedStringKey, description: LocalizedStringKey? = nil, options: Options = EmptyOptions())
    {
        self.options = options
        
        super.init(name: name, description: description)
        
        self.prepareOptions()
    }
    
    // Use `KeyPath` instead of `WritableKeyPath` as parameter to allow accessing projected property wrappers.
    public subscript<T>(dynamicMember keyPath: KeyPath<Options, T>) -> T {
        get {
            options[keyPath: keyPath]
        }
        set {
            guard let writableKeyPath = keyPath as? WritableKeyPath<Options, T> else { return }
            options[keyPath: writableKeyPath] = newValue
        }
    }
    
    public override var allOptions: [any AnyOption] {
        let features = Mirror(reflecting: self.options).children.compactMap { (child) -> (any AnyOption)? in
            let feature = child.value as? (any AnyOption)
            return feature
        }
        return features
    }
}

private extension Feature
{
    func prepareOptions()
    {
        // Update option keys + feature
        for case (let key?, let option as any _AnyOption) in Mirror(reflecting: self.options).children
        {
            // Remove leading underscore.
            let sanitizedKey = key.dropFirst()
            option.key = String(sanitizedKey)
            option.feature = self
        }
    }
}
