//
//  Bundle+SwizzleBundleID.swift
//  Delta
//
//  Created by Riley Testut on 8/7/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import ObjectiveC.runtime

extension Bundle
{
    @objc private var swizzled_infoDictionary: [String : Any]? {
        var infoDictionary = self.swizzled_infoDictionary
        #if BETA
        infoDictionary?[kCFBundleIdentifierKey as String] = "com.rileytestut.Delta.AltStore.Beta"
        #else
        infoDictionary?[kCFBundleIdentifierKey as String] = "com.rileytestut.Delta.AltStore"
        #endif
        return infoDictionary
    }

    public static func swizzleBundleID(handler: () -> Void)
    {
        let bundleClass: AnyClass = Bundle.self
        
        guard
            let originalMethod = class_getInstanceMethod(bundleClass, #selector(getter: Bundle.infoDictionary)),
            let swizzledMethod = class_getInstanceMethod(bundleClass, #selector(getter: Bundle.swizzled_infoDictionary))
        else {
            print("Failed to swizzle Bundle.infoDictionary.")
            return
        }
            
        method_exchangeImplementations(originalMethod, swizzledMethod)
        
        handler()
        
        method_exchangeImplementations(swizzledMethod, originalMethod)
    }
}
