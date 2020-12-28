//
//  Result+Success.swift
//  Harmony
//
//  Created by Riley Testut on 1/16/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

public extension Result where Success == Void
{
    static var success: Result {
        return .success(())
    }
}
