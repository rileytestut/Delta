//
//  MarketplaceDistributor.swift
//  Delta
//
//  Created by Riley Testut on 10/12/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import MarketplaceKit

// Our version of AppDistributor we can freely conform to protocols
enum MarketplaceDistributor: Hashable
{
    case appStore
    case altStore
    case testFlight
    case web
    case other
    
    init(_ distributor: AppDistributor)
    {
        switch distributor
        {
        case .appStore: self = .appStore
        case .testFlight: self = .testFlight
        case .web: self = .web
        case .marketplace(let bundleID):
            if bundleID == "io.altstore.AltStore"
            {
                self = .altStore
            }
            else
            {
                Logger.main.info("Unknown Marketplace bundle ID: \(bundleID, privacy: .public)")
                self = .other
            }
            
        case .other: self = .other
        @unknown default: self = .other
        }
    }
}
