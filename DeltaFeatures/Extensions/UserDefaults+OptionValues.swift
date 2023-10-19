//
//  UserDefaults+OptionValues.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

private func wrap<RawType, WrapperType: RawRepresentable>(rawValue: RawType, in type: WrapperType.Type) -> WrapperType?
{
    // Ensure rawValue is correct type.
    guard let rawValue = rawValue as? WrapperType.RawValue else { return nil }

    let representingValue = WrapperType.init(rawValue: rawValue)
    return representingValue
}

extension UserDefaults
{
    func setOptionValue<Value: OptionValue>(_ newValue: Value, forKey key: String) throws
    {
        switch newValue
        {
        // case .none/nil does _not_ catch nil values passed in,
        // but casting to NSSecureCoding then checking if NSNull does.
        // case .none: break
            
        case let secureCoding as any NSSecureCoding:
            if secureCoding is NSNull
            {
                // Removing value will make us return default value later,
                // which isn't what we want if we explicitly set nil.
                // Instead, we persist a dictionary with "isNil" key to let
                // us know we should return nil later, not the default value.
                let nilDictionary = ["isNil": true] as NSDictionary
                self.set(nilDictionary, forKey: key)
            }
            else
            {
                self.set(secureCoding, forKey: key)
            }
            
        case let rawRepresentable as any RawRepresentable:
            self.set(rawRepresentable.rawValue, forKey: key)
            
        case let codable as any Codable:
            let data = try PropertyListEncoder().encode(codable)
            self.set(data, forKey: key)
            
        default:
            // Try anyway ¯\_(ツ)_/¯
            self.set(newValue, forKey: key)
        }
    }
    
    // Returns Optional<Value>. If Value is already an Optional type, this will return a *nested* Optional<Optional<Value>>.
    // If return value == nil, value does _not_ yet exist, so we should use default value.
    // If return value == .some(nil) (aka nested nil), the value _does_ exist, and it is explicitly nil.
    func optionValue<Value: OptionValue>(forKey key: String, type: Value.Type) throws -> Value?
    {
        guard let rawValue = UserDefaults.standard.object(forKey: key) else { return nil }
        
        if let nilDictionary = rawValue as? [String: Bool], let isNil = nilDictionary["isNil"], let optionalType = Value.self as? any OptionalProtocol.Type, isNil
        {
            // Return nil nested inside Optional (aka .some(nil)).
            // Caller will treat it as non-nil and thus won't return default value.
            let nestedNil = optionalType.none as? Value
            return nestedNil
        }

        if let value = rawValue as? Value
        {
            return value
        }
        else if let optionalType = Value.self as? any OptionalProtocol.Type, let rawRepresentableType = optionalType.wrappedType as? any RawRepresentable.Type
        {
            // Open `rawRepresentableType` existential as concrete type so we can initialize RawRepresentable.
            // Don't cast via as? Value yet because that may result in `.some(nil)` if Value is optional.
            guard let rawRepresentable = wrap(rawValue: rawValue, in: rawRepresentableType) else {
                // Incorrect raw type, so return nil directly without nesting to use default value.
                return nil
            }
            
            // Return (potentially) nested optional.
            return rawRepresentable as? Value
        }
        else if let rawRepresentableType = Value.self as? any RawRepresentable.Type
        {
            // Open `rawRepresentableType` existential as concrete type so we can initialize RawRepresentable.
            // Don't cast via as? Value yet because that may result in `.some(nil)` if Value is optional.
            guard let rawRepresentable = wrap(rawValue: rawValue, in: rawRepresentableType) else {
                // Incorrect raw type, so return nil directly without nesting to use default value.
                return nil
            }
            
            // Return (potentially) nested optional.
            return rawRepresentable as? Value
        }
        else if let codableType = Value.self as? any Codable.Type, let data = rawValue as? Data
        {
            let decodedValue = try PropertyListDecoder().decode(codableType, from: data) as? Value
            return decodedValue
        }
        else
        {
            print("[RSTLog] Unsupported option type:", Value.self)
            
            // Return nil directly, no nesting.
            // Caller will treat this as nil and will return the default value instead.
            return nil
        }
    }
}
