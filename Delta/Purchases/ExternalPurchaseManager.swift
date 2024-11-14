//
//  ExternalPurchaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/30/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation
import StoreKit

class ExternalPurchaseManager
{
    static let shared = ExternalPurchaseManager()
    
    private(set) var supportsExternalPurchases: Bool = false
    
    private init()
    {
    }
}

extension ExternalPurchaseManager
{
    func prepare() async
    {
        // iOS 17.5 is earliest version that supports reporting purchases via Apple's External Purchase Server API.
        guard #available(iOS 17.5, *), AppStore.canMakePayments else { return }
        
        let canOpenPurchaseLink = await ExternalPurchaseLink.canOpen
        self.supportsExternalPurchases = canOpenPurchaseLink
    }
}
