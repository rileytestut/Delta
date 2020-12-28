//
//  UserDefaults+Harmony.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import Roxas

extension UserDefaults
{
    var isDebugModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "com.rileytestut.Harmony.Debug")
    }
}
