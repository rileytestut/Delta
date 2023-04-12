//
//  Array+Optionals.swift
//  DeltaFeatures
//
//  Created by Riley Testut on 4/12/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation

extension Array
{
    func appendingNil() -> [Element] where Element: OptionalProtocol, Element.Wrapped: LocalizedOptionValue
    {
        var values = self
        values.append(Element.none)
        return values
    }
}
