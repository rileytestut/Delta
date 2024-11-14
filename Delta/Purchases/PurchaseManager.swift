//
//  PurchaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/30/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation
import StoreKit

extension PurchaseManager
{
    static let friendZoneSubscriptionGroupID = "21579960"
}

class PurchaseManager
{
    static let shared = PurchaseManager()
    
    private(set) var supportsExternalPurchases: Bool = false
    
    private init()
    {
    }
    
    func prepare() async
    {
        do
        {
            // iOS 17.5 is earliest version that supports reporting purchases via Apple's External Purchase Server API.
            guard #available(iOS 17.5, *), AppStore.canMakePayments else { return }
            
            let canOpenPurchaseLink = await ExternalPurchaseLink.canOpen
            self.supportsExternalPurchases = canOpenPurchaseLink
            
            try await RevenueCatManager.shared.start()
        }
        catch
        {
            Logger.purchases.error("Failed to refresh RevenueCat customer info at launch. \(error.localizedDescription, privacy: .public)")
        }
    }
    
    @MainActor // @MainActor because some observers expect changes to happen on main thread.
    func update()
    {
        guard !self.isExperimentalFeaturesAvailable else { return }
        
        Logger.purchases.info("Experimental Features are no longer available, disabling all...")
        
        // Experimental Features no longer available, so disable them.
        for feature in ExperimentalFeatures.shared.allFeatures
        {
            feature.isEnabled = false
        }
    }
}

extension PurchaseManager
{
    @MainActor
    var isExperimentalFeaturesAvailable: Bool {
        #if BETA
        // Experimental features are always available in BETA version.
        return true
        #elseif LEGACY
        // Experimental features are NEVER available in LEGACY version.
        return false
        #else
        
        if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.hasBetaAccess
        {
            // User is signed into Patreon account and is active patron.
            return true
        }
        else if #available(iOS 17.5, *), RevenueCatManager.shared.hasBetaAccess
        {
            // User purchased in-app Friend Zone subscription.
            return true
        }
        else
        {
            return false
        }
        
        #endif
    }
    
    @MainActor
    var isPatronIconsAvailable: Bool {
        #if BETA
        // Patron icons are always available in BETA version.
        return true
        #elseif LEGACY
        // Patron icons are NEVER available in LEGACY version.
        return false
        #else

        if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.hasPastBetaAccess
        {
            // User is signed into Patreon account and is active patron.
            return true
        }
        else if #available(iOS 17.5, *), RevenueCatManager.shared.hasPastBetaAccess
        {
            // User purchased in-app Friend Zone subscription.
            return true
        }
        else
        {
            return false
        }

        #endif
    }
}

private extension PurchaseManager
{
    
}
