//
//  LocalizedOptionValue.swift
//  Delta
//
//  Created by Riley Testut on 4/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

public protocol LocalizedOptionValue: OptionValue, Hashable /* Identifiable */ // We don't want to implicitly conform types we don't own to `Identifiable`.
{
    static var localizedNilDescription: Text { get }
    
    var localizedDescription: Text { get }
}

public extension LocalizedOptionValue
{
    static var localizedNilDescription: Text {
        Text("None")
    }
}

// Provide `localizedDescription` implementation for standard library types.
public extension LocalizedOptionValue where Self: CustomStringConvertible
{
    var localizedDescription: Text {
        Text(String(describing: self))
    }
}

extension Int: LocalizedOptionValue {}
extension Int8: LocalizedOptionValue {}
extension Int16: LocalizedOptionValue {}
extension Int32: LocalizedOptionValue {}
extension Int64: LocalizedOptionValue {}

extension UInt: LocalizedOptionValue {}
extension UInt8: LocalizedOptionValue {}
extension UInt16: LocalizedOptionValue {}
extension UInt32: LocalizedOptionValue {}
extension UInt64: LocalizedOptionValue {}

extension Float: LocalizedOptionValue {}
extension Double: LocalizedOptionValue {}

extension String: LocalizedOptionValue {}
extension Bool: LocalizedOptionValue {}

extension Optional: LocalizedOptionValue where Wrapped: LocalizedOptionValue
{
    public var localizedDescription: Text {
        switch self
        {
        case .none: return Wrapped.localizedNilDescription
        case .some(let value): return value.localizedDescription
        }
    }
}
