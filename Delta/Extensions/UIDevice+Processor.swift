//
//  UIDevice+Processor.swift
//  Delta
//
//  Created by Riley Testut on 9/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import ARKit
import Metal

extension UIDevice
{
    private static var mtlDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
    
    var hasA9ProcessorOrBetter: Bool {
        // ARKit is only supported by devices with an A9 processor or better, according to the documentation.
        // https://developer.apple.com/documentation/arkit/arconfiguration/2923553-issupported
        return ARConfiguration.isSupported
    }
    
    var hasA11ProcessorOrBetter: Bool {
        guard let mtlDevice = UIDevice.mtlDevice else { return false }
        return mtlDevice.supportsFeatureSet(.iOS_GPUFamily4_v1) // iOS GPU Family 4 = A11 GPU
    }
    
    var supportsJIT: Bool {
        // As of iOS 14.4 beta 2, JIT is no longer supported :(
        // Hopefully this change is reversed before the public release...
        let ios14_4 = OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0)
        guard #available(iOS 14.2, *), !ProcessInfo.processInfo.isOperatingSystemAtLeast(ios14_4) else { return false }
        
        // JIT is supported on devices with an A12 processor or better running iOS 14.2 or later.
        // ARKit 3 is only supported by devices with an A12 processor or better, according to the documentation.
        return ARBodyTrackingConfiguration.isSupported
    }
}
