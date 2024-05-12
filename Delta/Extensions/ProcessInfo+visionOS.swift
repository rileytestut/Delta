//
//  ProcessInfo+visionOS.swift
//  Delta
//
//  Created by Riley Testut on 1/12/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation
import LocalAuthentication

extension ProcessInfo
{
    var isRunningOnVisionPro: Bool {
        // Returns true even when running on iOS :/
        // guard #available(visionOS 1, *) else { return false }
        // return true
        
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) // Sets .biometryType when called.
        
        // Can't reference `.opticID` due to bug with #available, so check if .biometryType isn't one of the other types instead.
        return context.biometryType != .faceID && context.biometryType != .touchID && context.biometryType != .none
    }
}
