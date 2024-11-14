//
//  RevenueCatManager.swift
//  Delta
//
//  Created by Riley Testut on 11/11/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import RevenueCat

private extension UserDefaults
{
    @NSManaged var revenueCatPurchasesSyncDate: Date?
}

@available(iOS 17.5, *)
extension RevenueCatManager
{
    static let didUpdateCustomerInfoNotification = Notification.Name("DLTADidUpdateCustomerInfoNotification")
    
    struct Entitlement: RawRepresentable, Codable, Hashable
    {
        static let betaAccess = Entitlement(rawValue: "beta-access")
        static let discord = Entitlement(rawValue: "discord")
        static let credits = Entitlement(rawValue: "credits")
        
        let rawValue: String
    }
    
    private struct ProductID: RawRepresentable, Codable, Hashable
    {
        static let friendZoneMonthly = ProductID(rawValue: "delta_friendzone_1299_month")
        
        let rawValue: String
    }
    
    enum Error: LocalizedError
    {
        case unknownProduct
        
        var errorDescription: String? {
            switch self
            {
            case .unknownProduct: return NSLocalizedString("There is no product with the requested ID.", comment: "")
            }
        }
    }
}

@available(iOS 17.5, *) @MainActor
class RevenueCatManager
{
    static let shared = RevenueCatManager()
    
    private(set) var isStarted: Bool = false
    
    private(set) var customerInfo: CustomerInfo? {
        didSet {
            PurchaseManager.shared.update()
            NotificationCenter.default.post(name: RevenueCatManager.didUpdateCustomerInfoNotification, object: self.customerInfo)
        }
    }
    
    var entitlements: [Entitlement: EntitlementInfo] {
        let entitlements = (self.customerInfo?.entitlements.all ?? [:]).map { (Entitlement(rawValue: $0), $1) }.reduce(into: [:]) { $0[$1.0] = $1.1 }
        return entitlements
    }
    
    var displayName: String? {
        let displayName = Keychain.shared.revenueCatDisplayName
        return displayName
    }
    
    var hasBetaAccess: Bool {
        guard let entitlement = self.entitlements[.betaAccess] else { return false }
        
        let hasBetaAccess = entitlement.isActive
        return hasBetaAccess
    }
    
    var hasPastBetaAccess: Bool {
        guard let customerInfo else { return false }
        
        let hasPastBetaAccess = customerInfo.allPurchasedProductIdentifiers.contains(RevenueCatManager.ProductID.friendZoneMonthly.rawValue)
        return hasPastBetaAccess
    }
    
    private init()
    {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        
        // Use anonymous user IDs.
        Purchases.configure(withAPIKey: "appl_kJGpGeyHNEybFWbrtftMmpkKOXL")
    }
    
    func start() async throws
    {
        guard !self.isStarted else { return }
        self.isStarted = true
        
        Task<Void, Never> {
            for await customerInfo in Purchases.shared.customerInfoStream
            {
                self.customerInfo = customerInfo
            }
        }
        
        if UserDefaults.standard.revenueCatPurchasesSyncDate == nil
        {
            // Initial launch, so sync all purchases.
            self.customerInfo = try await Purchases.shared.syncPurchases()
            UserDefaults.standard.revenueCatPurchasesSyncDate = .now
        }
        else
        {
            // Just fetch customer info.
            self.customerInfo = try await Purchases.shared.customerInfo(fetchPolicy: .cachedOrFetched)
        }
    }
    
    func setDisplayName(_ name: String) async throws
    {
        Keychain.shared.revenueCatDisplayName = name
        Purchases.shared.attribution.setDisplayName(name)
        
        _ = try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()        
    }
}

@available(iOS 17.5, *)
extension RevenueCatManager
{
    func purchaseFriendZoneSubscription() async throws
    {
        do
        {
            let products = await withCheckedContinuation { (continuation: CheckedContinuation<[StoreProduct], Never>) in
                Purchases.shared.getProducts([ProductID.friendZoneMonthly.rawValue]) { products in
                    continuation.resume(returning: products)
                }
            }
            
            guard let product = products.first else { throw Error.unknownProduct }
            
            Logger.purchases.info("Fetched RevenueCat product: \(product)")
            
            let (_, customerInfo, isCancelled) = try await Purchases.shared.purchase(product: product)
            guard !isCancelled else { throw CancellationError() }
            
            self.customerInfo = customerInfo
            
            Logger.purchases.info("Successfully purchased monthly Friend Zone subscription!")
        }
        catch
        {
            Logger.purchases.error("Failed to purchase Friend Zone subscription. \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    // May cause OS-level sign-in prompts to appear, so only call in response to user interaction.
    func requestRestorePurchases() async throws
    {
        do
        {
            self.customerInfo = try await Purchases.shared.restorePurchases()
        }
        catch
        {
            Logger.purchases.error("Failed to restore purchases. \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
