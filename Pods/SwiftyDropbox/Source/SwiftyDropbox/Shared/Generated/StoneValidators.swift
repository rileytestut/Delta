///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation

// The objects in this file are used by generated code and should not need to be invoked manually.

var _assertFunc: (Bool, String) -> Void = { cond, message in precondition(cond, message) }

public func setAssertFunc(_ assertFunc: @escaping (Bool, String) -> Void) {
    _assertFunc = assertFunc
}

public func arrayValidator<T>(minItems: Int? = nil, maxItems: Int? = nil, itemValidator: @escaping (T) -> Void) -> (Array<T>) -> Void {
    return { (value: Array<T>) -> Void in
        if let minItems = minItems {
            _assertFunc(value.count >= minItems, "\(value) must have at least \(minItems) items")
        }

        if let maxItems = maxItems {
            _assertFunc(value.count <= maxItems, "\(value) must have at most \(maxItems) items")
        }

        for el in value {
            itemValidator(el)
        }
    }
}

public func stringValidator(minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil) -> (String) -> Void {
    return { (value: String) -> Void in
        let length = value.count
        if let minLength = minLength {
            _assertFunc(length >= minLength, "\"\(value)\" must be at least \(minLength) characters")
        }
        if let maxLength = maxLength {
            _assertFunc(length <= maxLength, "\"\(value)\" must be at most \(maxLength) characters")
        }

        if let pat = pattern {
            // patterns much match entire input sequence
            let re = try! NSRegularExpression(pattern: "\\A(?:\(pat))\\z", options: NSRegularExpression.Options())
            let matches = re.matches(in: value, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 0, length: length))
            _assertFunc(matches.count > 0, "\"\(value) must match pattern \"\(re.pattern)\"")
        }
    }
}

public func comparableValidator<T: Comparable>(minValue: T? = nil, maxValue: T? = nil) -> (T) -> Void {
    return { (value: T) -> Void in
        if let minValue = minValue {
            _assertFunc(minValue <= value, "\(value) must be at least \(minValue)")
        }

        if let maxValue = maxValue {
            _assertFunc(maxValue >= value, "\(value) must be at most \(maxValue)")
        }
    }
}

public func nullableValidator<T>(_ internalValidator: @escaping (T) -> Void) -> (T?) -> Void {
    return { (value: T?) -> Void in
        if let value = value {
            internalValidator(value)
        }
    }
}

public func binaryValidator(minLength: Int?, maxLength: Int?) -> (Data) -> Void {
    return { (value: Data) -> Void in
        let length = value.count
        if let minLength = minLength {
            _assertFunc(length >= minLength, "\"\(value)\" must be at least \(minLength) bytes")
        }

        if let maxLength = maxLength {
            _assertFunc(length <= maxLength, "\"\(value)\" must be at most \(maxLength) bytes")
        }
    }
}
