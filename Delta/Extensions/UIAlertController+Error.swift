//
//  UIAlertController+Error.swift
//  INLINE
//
//  Created by Riley Testut on 11/27/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import Roxas
import Harmony

extension UIAlertController
{
    convenience init(title: String, error: Error)
    {
        let message: String
        
        if let error = error as? HarmonyError, let reason = error.failureReason
        {
            message = reason
        }
        else
        {
            message = error.localizedDescription
        }
        
        self.init(title: title, message: message, preferredStyle: .alert)
        
        self.addAction(.ok)
    }
}
