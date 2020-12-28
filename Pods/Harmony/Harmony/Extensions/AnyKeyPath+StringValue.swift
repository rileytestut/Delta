//
//  AnyKeyPath+StringValue.swift
//  Harmony
//
//  Created by Riley Testut on 12/8/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

extension AnyKeyPath
{
    var stringValue: String? {
        return self._kvcKeyPathString
    }
}
