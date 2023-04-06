//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine

struct EmptyOptions
{
}

class AnyFeature: ObservableObject
{
    let name: String
    let description: String?
    
    // Assigned to property name.
    var key: String = ""
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: self.key) }
        set {
            self.objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: self.key)
        }
    }
    
    init(name: String, description: String? = nil)
    {
        self.name = name
        self.description = description
    }
    
    var allOptions: [any AnyFeatureSetting] { [] }
}

extension AnyFeature: Identifiable
{
    var id: String { self.key }
}

@propertyWrapper @dynamicMemberLookup
final class Feature<Options>: AnyFeature
{
    var wrappedValue: some AnyFeature {
        return self
    }
    
    private let options: Options
    
    init(name: String, description: String? = nil, options: Options = EmptyOptions())
    {
        self.options = options
        
        super.init(name: name, description: description)
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Options, T>) -> T
    {
        let value = options[keyPath: keyPath]
        return value
    }
    
    override var allOptions: [any AnyFeatureSetting] {
        let features = Mirror(reflecting: self.options).children.compactMap { [weak self] (child) -> (any AnyFeatureSetting)? in
            var feature = child.value as? (any AnyFeatureSetting)
            feature?.parentFeature = self
            return feature
        }
        return features
    }
}

protocol AnyFeatureSetting<Value>: Identifiable
{
    associatedtype Value
    
    var name: String { get }
    var description: String? { get }
    var key: String { get }
    
    var detailView: () -> AnyView? { get }
    
    var parentFeature: AnyFeature? { get set }
    var wrappedValue: Value { get }
}

extension AnyFeatureSetting
{
    var id: String { key }
}

func makeType<RepresentingType: RawRepresentable, RawType>(_ type: RepresentingType.Type, from rawValue: RawType) -> RepresentingType?
{
    guard let rawValue = rawValue as? RepresentingType.RawValue else { return nil }
    
    let representingValue = RepresentingType.init(rawValue: rawValue)
    return representingValue
}

@propertyWrapper
class FeatureSetting<Value>: AnyFeatureSetting
{
    weak var parentFeature: AnyFeature?
    
    var wrappedValue: Value {
        get {
            let wrappedValue: Value?
            
            guard let rawValue = UserDefaults.standard.object(forKey: self.key) else {
                return self.initialValue
            }

            if let value = rawValue as? Value
            {
                wrappedValue = value
            }
            else if let rawRepresentableType = Value.self as? any RawRepresentable.Type
            {
                let rawRepresentable = makeType(rawRepresentableType, from: rawValue) as! Value
                wrappedValue = rawRepresentable
            }
            else if let codableType = Value.self as? any Codable.Type, let data = rawValue as? Data
            {
                let decodedValue = try? PropertyListDecoder().decode(codableType, from: data) as? Value
                wrappedValue = decodedValue
            }
            else
            {
                wrappedValue = nil
            }
            
            return wrappedValue ?? self.initialValue
        }
        set {
            Task { @MainActor in
                // Delay to avoid "Publishing changes from within view updates is not allowed" runtime warning.
                (self.parentFeature?.objectWillChange as? ObservableObjectPublisher)?.send()
            }
            
            switch newValue
            {
            case let rawRepresentable as any RawRepresentable:
                UserDefaults.standard.set(rawRepresentable.rawValue, forKey: self.key)
                
            case let secureCoding as any NSSecureCoding:
                UserDefaults.standard.set(secureCoding, forKey: self.key)
                
            case let codable as any Codable:
                do
                {
                    let data = try PropertyListEncoder().encode(codable)
                    UserDefaults.standard.set(data, forKey: self.key)
                }
                catch
                {
                    print("Failed to encode FeatureSetting value.", error)
                }
                
            default:
                // Try anyway.
                UserDefaults.standard.set(newValue, forKey: self.key)
            }
        }
    }
    
    private let initialValue: Value
    
    var projectedValue: FeatureSetting<Value> { self }
    
    var name: String
    var description: String?
    var key: String
    
    var detailView: () -> AnyView?
    
    private var valueBinding: Binding<Value> {
        Binding(get: {
            self.wrappedValue
        }, set: {
            self.wrappedValue = $0
        })
    }
    
    init(wrappedValue: Value, name: String, description: String? = nil, key: String)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.key = key
        
        self.detailView = { nil }
    }
    
    init(wrappedValue: Value, name: String, description: String? = nil, key: String, @ViewBuilder detailView: @escaping (Binding<Value>) -> some View)
    {
        self.initialValue = wrappedValue
        
        self.name = name
        self.description = description
        self.key = key
        
        self.detailView = { nil }
        
        self.detailView = {
            let view = detailView(self.valueBinding)
            return AnyView(
                Form {
                    view
                }
            )
        }
    }
}

protocol ExperimentalFeature: Identifiable, ObservableObject
{
    static var settingsKey: String { get }

    var name: String { get }
    var description: String? { get }
}

extension ExperimentalFeature
{
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.settingsKey) }
        set {
            (self.objectWillChange as? ObservableObjectPublisher)?.send()
            UserDefaults.standard.set(newValue, forKey: Self.settingsKey)
        }
    }

    var id: String {
        return Self.settingsKey
    }
    
    var settings: [any AnyFeatureSetting] { []
//        let experimentalFeatures = Mirror(reflecting: self).children.compactMap { [weak self] (child) -> (any AnyFeatureSetting)? in
//            guard var setting = child.value as? (any AnyFeatureSetting) else { return nil }
//            setting.parentFeature = self
//            return setting
//        }
//        return experimentalFeatures
    }
}
