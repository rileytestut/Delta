//
//  AnyCodable.swift
//  Harmony
//
//  Created by Riley Testut on 4/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//
//  Heavily based on Flight School's AnyCodable by Mattt Thompson (https://github.com/Flight-School/AnyCodable)
//

import Foundation

struct AnyCodable: Codable
{
    let value: Any

    init<T>(_ value: T?)
    {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()

        if container.decodeNil()
        {
            self.init(NSNull())
        }
        else if let bool = try? container.decode(Bool.self)
        {
            self.init(bool)
        }
        else if let int = try? container.decode(Int.self)
        {
            self.init(int)
        }
        else if let uint = try? container.decode(UInt.self)
        {
            self.init(uint)
        }
        else if let double = try? container.decode(Double.self)
        {
            self.init(double)
        }
        else if let string = try? container.decode(String.self)
        {
            self.init(string)
        }
        else if let array = try? container.decode([AnyCodable].self)
        {
            self.init(array.map { $0.value })
        }
        else if let dictionary = try? container.decode([String: AnyCodable].self)
        {
            self.init(dictionary.mapValues { $0.value })
        }
        else
        {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded.")
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        
        switch self.value
        {
        case let number as NSNumber: try self.encode(nsnumber: number, into: &container)
        case is NSNull: try container.encodeNil()
        case is Void: try container.encodeNil()
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let int8 as Int8: try container.encode(int8)
        case let int16 as Int16: try container.encode(int16)
        case let int32 as Int32: try container.encode(int32)
        case let int64 as Int64: try container.encode(int64)
        case let uint as UInt: try container.encode(uint)
        case let uint8 as UInt8: try container.encode(uint8)
        case let uint16 as UInt16: try container.encode(uint16)
        case let uint32 as UInt32: try container.encode(uint32)
        case let uint64 as UInt64: try container.encode(uint64)
        case let float as Float: try container.encode(float)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let date as Date: try container.encode(date)
        case let url as URL: try container.encode(url)
        case let array as [Any?]: try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any?]: try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded.")
            throw EncodingError.invalidValue(self.value, context)
        }
    }
    
    private func encode(nsnumber: NSNumber, into container: inout SingleValueEncodingContainer) throws
    {
        switch CFNumberGetType(nsnumber)
        {
        case .charType: try container.encode(nsnumber.boolValue)
        case .sInt8Type: try container.encode(nsnumber.int8Value)
        case .sInt16Type: try container.encode(nsnumber.int16Value)
        case .sInt32Type: try container.encode(nsnumber.int32Value)
        case .sInt64Type: try container.encode(nsnumber.int64Value)
        case .shortType: try container.encode(nsnumber.uint16Value)
        case .longType: try container.encode(nsnumber.uint32Value)
        case .longLongType: try container.encode(nsnumber.uint64Value)
        case .intType, .nsIntegerType, .cfIndexType: try container.encode(nsnumber.intValue)
        case .floatType, .float32Type: try container.encode(nsnumber.floatValue)
        case .doubleType, .float64Type, .cgFloatType: try container.encode(nsnumber.doubleValue)
        @unknown default: fatalError()
        }
    }
}
