//
//  Bundle+Resources.swift
//  DeltaCore
//
//  Created by Riley Testut on 2/3/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

extension Bundle
{
    class var resources: Bundle {
        #if FRAMEWORK
        let bundle = Bundle(for: RingBuffer.self)
        #elseif STATIC_LIBRARY
        let bundle: Bundle
        if let bundleURL = Bundle.main.url(forResource: "DeltaCore", withExtension: "bundle")
        {
            bundle = Bundle(url: bundleURL)!
        }
        else
        {
            bundle = .main
        }
        #else
        let bundle = Bundle.main
        #endif
        
        return bundle
    }
}
