//
//  OptionValue.swift
//  Delta
//
//  Created by Riley Testut on 4/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

public protocol OptionValue
{
}

extension Data: OptionValue {}

extension Optional: OptionValue where Wrapped: OptionValue {}

extension Array: OptionValue where Element: OptionValue {}
extension Set: OptionValue where Element: OptionValue {}
extension Dictionary: OptionValue where Key: OptionValue, Value: OptionValue {}
