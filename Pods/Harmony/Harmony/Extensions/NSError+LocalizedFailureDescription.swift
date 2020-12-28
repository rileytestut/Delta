//
//  NSError+LocalizedFailureDescription.swift
//  Harmony
//
//  Created by Riley Testut on 1/29/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

extension NSError
{
    var localizedFailureDescription: String? {
        let description = self.userInfo[NSLocalizedFailureErrorKey] as? String
        return description
    }
}
