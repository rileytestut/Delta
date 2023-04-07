//
//  UserDefaults+FeatureOptions.swift
//  Delta
//
//  Created by Riley Testut on 4/7/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

extension UserDefaults
{
    func setOptionValue(_ newValue: some Any, forKey key: String) throws
    {
        switch newValue
        {
        case let rawRepresentable as any RawRepresentable: self.set(rawRepresentable.rawValue, forKey: key)
        case let secureCoding as any NSSecureCoding: self.set(secureCoding, forKey: key)
        case let codable as any Codable:
            let data = try PropertyListEncoder().encode(codable)
            UserDefaults.standard.set(data, forKey: key)
            
        default:
            // Try anyway.
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    func optionValue<Value>(forKey key: String, type: Value.Type) throws -> Value?
    {
        guard let rawValue = UserDefaults.standard.object(forKey: key) else { return nil }
                
        if let value = rawValue as? Value
        {
            return value
        }
        else if let rawRepresentableType = Value.self as? any RawRepresentable.Type
        {
            // Open `rawRepresentableType` existential as concrete type so we can initialize RawRepresentable.
            func wrap<RawType, WrapperType: RawRepresentable>(rawValue: RawType, in type: WrapperType.Type) -> WrapperType?
            {
                // Ensure rawValue is correct type.
                guard let rawValue = rawValue as? WrapperType.RawValue else { return nil }

                let representingValue = WrapperType.init(rawValue: rawValue)
                return representingValue
            }
                        
            let rawRepresentable = wrap(rawValue: rawValue, in: rawRepresentableType) as? Value
            return rawRepresentable
        }
        else if let codableType = Value.self as? any Codable.Type, let data = rawValue as? Data
        {
            let decodedValue = try PropertyListDecoder().decode(codableType, from: data) as? Value
            return decodedValue
        }
        else
        {
            return nil
        }
    }
}
