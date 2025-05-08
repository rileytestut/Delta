//
//  MockPurchaseManager.swift
//  Delta
//
//  Created by Riley Testut on 5/8/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

class PurchaseManager
{
    static let shared = PurchaseManager()
    
    var supportsExternalPurchases: Bool { true }
    
    private init()
    {
    }
    
    @available(iOS 17.5, *)
    func prepare() async
    {
    }
    
    @MainActor
    func update()
    {
    }
}

extension PurchaseManager
{
    @MainActor
    var isActivePatron: Bool {
        true
    }
    
    @MainActor
    var isExperimentalFeaturesAvailable: Bool {
        true
    }
    
    @MainActor
    var supportsExperimentalFeatures: Bool {
        true
    }
    
    @MainActor
    var isPatronIconsAvailable: Bool {
        true
    }
}
