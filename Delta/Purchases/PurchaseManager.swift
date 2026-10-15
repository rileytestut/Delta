//
//  PurchaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/30/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation
import StoreKit
import MarketplaceKit
import SwiftUI

import DeltaFeatures

private extension URL
{
    #if STAGING
    static let patreonTiers = URL(string: "https://f000.backblazeb2.com/file/altstore-staging/patreon/patreon-tiers.json")!
    #else
    static let patreonTiers = URL(string: "https://cdn.altstore.io/file/altstore/patreon/patreon-tiers.json")!
    #endif
}

enum PurchaseError: LocalizedError
{
    case paymentsNotAllowed
    case externalPurchasesNotAllowed
    
    var errorDescription: String? {
        switch self
        {
        case .paymentsNotAllowed: String(localized: "Payments are not allowed for the current iCloud user.")
        case .externalPurchasesNotAllowed: String(localized: "The current iCloud user is not eligible to make external purchases.")
        }
    }
}

extension PurchaseManager
{
    struct PatreonTierOffering
    {
        var price: Decimal
        var tax: Decimal
        var currency: String
    }
    
    struct Donation
    {
        var amount: Decimal
        var currency: String
        var service: Service
    }
    
    enum Service: Hashable, Identifiable
    {
        case patreon
        case iap
        
        var id: Self { self }
        
        var localizedTitle: String {
            switch self
            {
            case .patreon: return String(localized: "Patreon")
            case .iap: return String(localized: " In-App Purchase")
            }
        }
        
        var imageResource: ImageResource {
            switch self
            {
            case .patreon: return .patreonLogo
            case .iap: return .inAppPurchaseLogo
            }
        }
    }
}

@Observable @MainActor
class PurchaseManager
{
    static let shared = PurchaseManager()
    
    private(set) var isActivePatron: Bool = false
    
    var supportsExternalPurchases: Bool {
        guard !UserDefaults.standard.isExternalPurchaseLinkDisabled else { return false }
        return _supportsExternalPurchases
    }
    private var _supportsExternalPurchases: Bool = false
    
    var supportsInAppPurchase: Bool {
        // Both App Store and TestFlight (and App Review via Other) support IAP
        return self.distributor != .altStore
    }
    
    private(set) var distributor: MarketplaceDistributor = .appStore
    
    // This can be non-nil even if supportsExternalPurchases is false due to iOS version requirements.
    // However, if supportsExternalPurchases is true this will never be nil.
    private(set) var externalPurchaseRegion: ExternalPurchaseRegion?
    
    private(set) var commissionRegion: String? // Determines whether we must report CTC transactions
    private(set) var storeRegion: String? // Determines whether we can offer external purchases or not
    
    private var revenueCatObserver: NSObjectProtocol?
    private var patreonObserver: NSObjectProtocol?
    
    private init()
    {
    }
    
    @available(iOS 17.5, *) // iOS 17.5 is earliest version that supports reporting purchases via Apple's External Purchase Server API.
    func prepare() async
    {
        #if APP_STORE
        
        // Override value for APP_STORE builds.
        self.distributor = .appStore
        
        #else
        
        do
        {
            let appDistributor = try await AppDistributor.current
            self.distributor = MarketplaceDistributor(appDistributor)
        }
        catch
        {
            Logger.main.error("Failed to determine AppDistributor. \(error.localizedDescription, privacy: .public)")
        }
        
        #endif
        
        self.storeRegion = await Storefront.current?.countryCode.uppercased()
        
        let deviceIdiom = UIDevice.current.userInterfaceIdiom
        
        if self.distributor == .altStore
        {
            if #available(iOS 26.2, *)
            {
                // Delta always supports external purchases outside App Store on iOS 26.2 or later (due to CTC token API being unavailable before then).
                self._supportsExternalPurchases = true
            }
            else
            {
                self._supportsExternalPurchases = false
            }
        }
        else if let storeRegion, let externalPurchaseRegion = ExternalPurchaseRegion(countryCode: storeRegion)
        {
            self.externalPurchaseRegion = externalPurchaseRegion
            
            switch externalPurchaseRegion {
            case .usa:
                // USA supports external purchases for iPhone and iPad on all iOS versions
                self._supportsExternalPurchases = true
                
            case .japan:
                if #available(iOS 26.4, *), deviceIdiom == .phone
                {
                    // Japan supports external purchases on iPhone on 26.4 or later (due to External Purchase Server Purchase API not supported before then).
                    self._supportsExternalPurchases = true
                }
                
            case .brazil:
                if #available(iOS 26.5, *), deviceIdiom == .phone
                {
                    // Brazil supports external purchases on iPhone on 26.5 or later
                    self._supportsExternalPurchases = true
                }
                
            case _ where externalPurchaseRegion.isEUCountry:
                if #available(iOS 26.6, *)
                {
                    // EU supports external purchases on iPhone and iPad on 26.6 or later
                    self._supportsExternalPurchases = true
                }
            
            default:
                self._supportsExternalPurchases = false
            }
            
            if self._supportsExternalPurchases
            {
                Logger.main.info("User's storefront is a region that allows external purchases (\(storeRegion, privacy: .public)), enabling external purchases...")
            }
        }
        
        if #available(iOS 26.4, *)
        {
            self.commissionRegion = await AppDistributor.eligibilityRegion
        }
        else
        {
            // Can't retrieve eligibilityRegion directly, so fall back to user's storefront region pre-iOS 26.4
            self.commissionRegion = self.externalPurchaseRegion?.region
        }
        
        if let commissionRegion, self.distributor == .altStore
        {
            // Set ExternalPurchaseRegion so its non-nil even when outside App Store, to make logic paths easier
            self.externalPurchaseRegion = ExternalPurchaseRegion(region: commissionRegion)
        }
        
        do
        {
            try await RevenueCatManager.shared.start()
        }
        catch
        {
            Logger.purchases.error("Failed to refresh RevenueCat customer info at launch. \(error.localizedDescription, privacy: .public)")
        }
        
        self.updateIsActivePatron()
        
        self.revenueCatObserver = NotificationCenter.default.addObserver(forName: RevenueCatManager.didUpdateCustomerInfoNotification, object: nil, queue: nil) { _ in
            Task<Void, Never> { @MainActor in
                self.updateIsActivePatron()
            }
        }
        
        self.patreonObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil) { notification in
            guard let userInfo = notification.userInfo else { return }
            
            let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
            let refreshedObjects = userInfo[NSRefreshedObjectsKey] as? Set<NSManagedObject> ?? []
            
            // Merged changes from background contexts may be reported as refreshed objects rather than updated objects.
            let allObjects = insertedObjects.union(updatedObjects).union(deletedObjects).union(refreshedObjects)
            let didChangePatreonAccount = allObjects.contains { $0 is PatreonAccount }

            guard didChangePatreonAccount else { return }

            Task<Void, Never> { @MainActor in
                self.updateIsActivePatron()
            }
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
            guard let feature = feature as? any EnabledFeature else { continue }
            feature.isEnabled = false
        }
    }
}

extension PurchaseManager
{
    func fetchPatreonOffering(tierID: String, region: ExternalPurchaseRegion) async throws -> PatreonTierOffering?
    {
        let (data, urlResponse) = try await URLSession.shared.data(from: .patreonTiers)
        
        if let response = urlResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.patreonTiers])
            }
        }
        
        struct Response: Decodable
        {
            struct Region: Decodable
            {
                var currency: String
                var taxPercentage: Decimal
                
                var tiers: [String: Offering]
            }
            
            struct Offering: Decodable
            {
                var price: Decimal
            }
            
            var regions: [String: Region]
        }
                
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let region = response.regions[region.region], let tier = region.tiers[tierID] else { return nil }
        
        let taxAmount = tier.price * (region.taxPercentage / 100)
        let offering = PatreonTierOffering(price: tier.price, tax: taxAmount, currency: region.currency)
        return offering
    }
    
    func join(_ tier: PatreonAPI.Tier, presentingViewController: UIViewController) async throws -> PatreonAccount
    {
        if self.distributor != .altStore
        {
            // Always check whether payments are allowed in App Store when distributed with App Store, even if region doesn't require an entitlement.
            guard AppStore.canMakePayments else { throw PurchaseError.paymentsNotAllowed }
            
            if let region = PurchaseManager.shared.externalPurchaseRegion, region.requiresExternalPurchasesOrOffersEntitlement, #available(iOS 18.1, *)
            {
                guard await ExternalPurchaseCustomLink.isEligible else { throw PurchaseError.externalPurchasesNotAllowed }
                
                if !UserDefaults.standard.hideIAPDisclosureScreen
                {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        
                        let sheet = IAPDisclosureSheet { showNextTime in
                            UserDefaults.standard.hideIAPDisclosureScreen = !showNextTime
                            continuation.resume()
                            presentingViewController.dismiss(animated: true)
                        } cancelHandler: {
                            continuation.resume(throwing: CancellationError())
                            presentingViewController.dismiss(animated: true)
                        }
                            .ignoresSafeArea()
                        
                        let hostingController = UIHostingController(rootView: sheet)
                        presentingViewController.present(hostingController, animated: true, completion: nil)
                    }
                }
            }
        }
        
        let commissionToken = try await CommissionManager.shared.requestCommissionToken()
        
        do
        {
            let (userAccount, pledge, isNewPatron) = try await PatreonAPI.shared.join(tier, presentingViewController: presentingViewController)
            
            if let commissionToken
            {
                if isNewPatron
                {
                    // New patron, so we need to report CTC
                    Logger.main.info("New patron!! We do need to report CTC...")
                    
                    try await CommissionManager.shared.link(token: commissionToken, withAccountID: userAccount.identifier, membershipID: pledge.identifier)
                }
                else
                {
                    // Existing patron, so no need to report CTC
                    Logger.main.info("Existing patron! No need to report CTC.")
                }
            }
            
            await DatabaseManager.shared.performBackgroundTask { context in
                do
                {
                    _ = PatreonAccount(account: userAccount, context: context)
                    try context.save()
                }
                catch
                {
                    Logger.main.error("Failed to save fetched PatreonAPI.UserAccount \(userAccount.identifier). \(error.localizedDescription, privacy: .public)")
                }
            }
            
            let patreonAccount = DatabaseManager.shared.patreonAccount() ?? PatreonAccount(account: userAccount, context: DatabaseManager.shared.viewContext)
            return patreonAccount
        }
        catch is CancellationError
        {
            if let commissionToken, let account = DatabaseManager.shared.patreonAccount()
            {
                do
                {
                    // User is signed in but not patron of this tier, so link their account in case they join later (within Apple's window).
                    try await CommissionManager.shared.link(token: commissionToken, withAccountID: account.identifier, membershipID: nil)
                }
                catch
                {
                    Logger.main.error("Failed to link commission token \(commissionToken, privacy: .public) with non-member Patreon account \(account.identifier, privacy: .public). \(error.localizedDescription, privacy: .public)")
                }
            }
            
            throw CancellationError()
        }
    }
}

extension PurchaseManager
{
    private func updateIsActivePatron()
    {
        if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.hasBetaAccess
        {
            // User is signed into Patreon account and is an active patron.
            self.isActivePatron = true
        }
        else if RevenueCatManager.shared.hasBetaAccess
        {
            self.isActivePatron = true
        }
        else
        {
            self.isActivePatron = false
        }
    }
    
    var activeDonation: Donation? {
        get async {
            if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.isPatron, let currency = patreonAccount.pledgeCurrency, let pledgeAmount = patreonAccount.pledgeAmount
            {
                let donation = Donation(amount: pledgeAmount as Decimal, currency: currency, service: .patreon)
                return donation
            }
            // TODO: Get user's actual subscription price, not current product price (which may be different)
            else if let subscription = RevenueCatManager.shared.activeSubscription, let product = await RevenueCatManager.shared.fetch(subscription), let currency = product.currency
            {
                let donation = Donation(amount: product.price, currency: currency, service: .iap)
                return donation
            }
            else
            {
                return nil
            }
        }
    }
    
    var isExperimentalFeaturesAvailable: Bool {
        #if BETA
        // Experimental features are always available in BETA version.
        return true
        #elseif LEGACY
        // Experimental features are NEVER available in LEGACY version.
        return false
        #else
        
        if self.isActivePatron
        {
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
    
    var supportsExperimentalFeatures: Bool {
        // As of Delta 2.0, we always support Experimental Features regardless of distribution method.
        return true
    }
    
    var isPatronIconsAvailable: Bool {
        #if BETA
        // Patron icons are always available in BETA version.
        return true
        #elseif LEGACY
        // Patron icons are NEVER available in LEGACY version.
        return false
        #else

        if self.isActivePatron
        {
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

fileprivate extension UserDefaults
{
    @NSManaged
    var hideIAPDisclosureScreen: Bool
}
