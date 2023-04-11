//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

struct EmptyOptions {}

class AnyFeature: ObservableObject
{
    let name: LocalizedStringKey
    let description: LocalizedStringKey?
    
    // Assigned to property name.
    var key: String = ""
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: self.key) }
        set {
            self.objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: self.key)
        }
    }
    
    init(name: LocalizedStringKey, description: LocalizedStringKey? = nil)
    {
        self.name = name
        self.description = description
    }
    
    // Overridden
    var allOptions: [any AnyOption] { [] }
}

extension AnyFeature: Identifiable
{
    var id: String { self.key }
}

@propertyWrapper @dynamicMemberLookup
final class Feature<Options>: AnyFeature
{
    private var options: Options
    
    var wrappedValue: some Feature {
        return self
    }
    
    init(name: LocalizedStringKey, description: LocalizedStringKey? = nil, options: Options = EmptyOptions())
    {
        self.options = options
        
        super.init(name: name, description: description)
        
        self.prepareOptions()
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Options, T>) -> T {
        get {
            options[keyPath: keyPath]
        }
        set {
            guard let writableKeyPath = keyPath as? WritableKeyPath<Options, T> else { return }
            options[keyPath: writableKeyPath] = newValue
        }
    }
    
    override var allOptions: [any AnyOption] {
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
            option.key = key
            option.feature = self
        }
    }
}
