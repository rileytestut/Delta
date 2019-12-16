//
//  UIDevice+Processor.swift
//  Delta
//
//  Created by Riley Testut on 9/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
#if os(iOS)
import ARKit
#endif

extension UIDevice
{
    var hasA9ProcessorOrBetter: Bool {
        // ARKit is only supported by devices with an A9 processor or better, according to the documentation.
        // https://developer.apple.com/documentation/arkit/arconfiguration/2923553-issupported
        #if os(iOS)
        return ARConfiguration.isSupported
        #elseif os(tvOS)
        // TV HD has A8 chip, and TV 4K has A10X chip. Best to return true here for now
        return true
        #else
        return false
        #endif
    }
}
