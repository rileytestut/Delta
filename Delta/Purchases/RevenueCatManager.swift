//
//  RevenueCatManager.swift
//  Delta
//
//  Created by Riley Testut on 11/11/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import StoreKit
import RevenueCat

private extension UserDefaults
{
    @NSManaged var revenueCatPurchasesSyncDate: Date?
}

@available(iOS 17.5, *)
extension RevenueCatManager
{
    static let didUpdateCustomerInfoNotification = Notification.Name("DLTADidUpdateCustomerInfoNotification")
    
    struct User: Decodable
    {
        var id: String
        var name: String?
    }
    
    struct Entitlement: RawRepresentable, Codable, Hashable
    {
        static let betaAccess = Entitlement(rawValue: "beta-access")
        static let discord = Entitlement(rawValue: "discord")
        static let credits = Entitlement(rawValue: "credits")
        
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
    
    enum Subscription
    {
        case earlyAdopter
        case communityMember
        case friendZone
        
        var title: String {
            switch self
            {
            case .earlyAdopter: return String(localized: "Early Adopter")
            case .communityMember: return String(localized: "Community Member")
            case .friendZone: return String(localized: "Friend Zone")
            }
        }
        
        fileprivate var productID: ProductID {
            switch self
            {
            case .earlyAdopter: return .earlyAdopterMonthly
            case .communityMember: return .communityMemberMonthly
            case .friendZone: return .friendZoneMonthly
            }
        }
    }
}

@available(iOS 17.5, *)
private extension RevenueCatManager
{
    static let projectID = "bcb273c1"
    static let apiKeyV1 = "sk_CnWLjZPMhUXNCsYCniuCbEGxrmjby"
    static let apiKeyV2 = "sk_DNGXQqVGzSAneClgROmffzVjXNBLQ"
    
    struct ProductID: RawRepresentable, Codable, Hashable
    {
        static let earlyAdopterMonthly = ProductID(rawValue: "delta_earlyadopter_1000_month")
        static let communityMemberMonthly = ProductID(rawValue: "delta_communitymember_1500_month")
        static let friendZoneMonthly = ProductID(rawValue: "delta_friendzone_3000_month")
        
        let rawValue: String
    }
    
    struct Subscriber: Decodable
    {
        struct Attribute: Codable
        {
            struct Key: RawRepresentable, Codable, Hashable, CodingKeyRepresentable
            {
                // RevenueCat Reserved
                static let email = Key(rawValue: "$email")
                static let name = Key(rawValue: "$displayName")
                
                let rawValue: String
            }
            
            var value: String
            var updated_at_ms: Int64?
        }
        
        var first_seen: Date
        var subscriber_attributes: [Attribute.Key: Attribute]?
    }
    
    struct GetSubscriberResponse: Decodable
    {
        var request_date: Date // ISO 8601
        var request_date_ms: UInt64 // Unix timestamp
        
        var subscriber: Subscriber
    }
    
    private struct FetchCustomersResponse: Decodable
    {
        struct Customer: Decodable
        {
            var id: String
        }
        
        var items: [Customer]
        
        var next_page: String?
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
    
    var emailAddress: String? {
        let emailAddress = Keychain.shared.revenueCatEmailAddress
        return emailAddress
    }
    
    var hasBetaAccess: Bool {
        guard let entitlement = self.entitlements[.betaAccess] else { return false }
        
        let hasBetaAccess = entitlement.isActive
        return hasBetaAccess
    }
    
    var hasPastBetaAccess: Bool {
        let entitlement = self.entitlements[.betaAccess]
        
        let hasPastBetaAccess = (entitlement != nil)
        return hasPastBetaAccess
    }
    
    private let baseURL = URL(string: "https://api.revenuecat.com")!
    
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
        
        Task<Void, Never> {
            for await purchaseIntent in PurchaseIntent.intents
            {
                do
                {
                    let productID = ProductID(rawValue: purchaseIntent.product.id)
                    switch productID
                    {
                    case .earlyAdopterMonthly: try await self.purchase(.earlyAdopter)
                    case .communityMemberMonthly: try await self.purchase(.communityMember)
                    case .friendZoneMonthly: try await self.purchase(.friendZone)
                    default: break
                    }
                }
                catch
                {
                    Logger.purchases.error("Failed to continue purchase \(purchaseIntent.product.id) in-app. \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    func setDisplayName(_ name: String) async throws
    {
        Keychain.shared.revenueCatDisplayName = name
        Purchases.shared.attribution.setDisplayName(name)
        
        _ = try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()        
    }
    
    func setEmailAddress(_ emailAddress: String) async throws
    {
        Keychain.shared.revenueCatEmailAddress = emailAddress
        Purchases.shared.attribution.setEmail(emailAddress)
        
        _ = try await Purchases.shared.syncAttributesAndOfferingsIfNeeded()
    }
}

@available(iOS 17.5, *)
extension RevenueCatManager
{
    func purchase(_ subscription: Subscription) async throws
    {
        do
        {
            let products = await withCheckedContinuation { (continuation: CheckedContinuation<[StoreProduct], Never>) in
                Purchases.shared.getProducts([subscription.productID.rawValue]) { products in
                    continuation.resume(returning: products)
                }
            }
            
            guard let product = products.first else { throw Error.unknownProduct }
            
            Logger.purchases.info("Fetched RevenueCat product: \(product)")
            
            let (_, customerInfo, isCancelled) = try await Purchases.shared.purchase(product: product)
            guard !isCancelled else { throw CancellationError() }
            
            self.customerInfo = customerInfo
            
            Logger.purchases.info("Successfully purchased \(subscription.title, privacy: .public) subscription!")
        }
        catch
        {
            Logger.purchases.error("Failed to purchase \(subscription.title, privacy: .public) subscription. \(error.localizedDescription, privacy: .public)")
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

@available(iOS 17.5, *)
extension RevenueCatManager
{
    @discardableResult
    func fetchFriendZoneUsers() async throws -> [User]
    {
        let apiURL = URL(string: "https://api.revenuecat.com/v2/projects/\(RevenueCatManager.projectID)/customers?limit=1000")!
        
        var userIDs: Set<String> = []
        
        func fetchPatrons(url: URL) async throws
        {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(RevenueCatManager.apiKeyV2)", forHTTPHeaderField: "Authorization")
            
            let response = try await self.send(request, expecting: FetchCustomersResponse.self)
            
            let ids = response.items.map(\.id)
            userIDs.formUnion(ids)
            
            if let nextPage = response.next_page, let nextURL = URL(string: nextPage)
            {
                try await fetchPatrons(url: nextURL)
            }
        }
        
        try await fetchPatrons(url: apiURL)
        
        // Fetch customer info for each userID.
        let users = try await withThrowingTaskGroup(of: User.self) { taskGroup in
            for userID in userIDs
            {
                _ = taskGroup.addTaskUnlessCancelled {
                    try await self.fetchUser(id: userID)
                }
            }
            
            var users: [User] = []
            
            for try await user in taskGroup
            {
                users.append(user)
            }
            
            return users
        }
        
        return users
    }
    
    @discardableResult
    func fetchUser(id: String) async throws -> User
    {
        // Creates user if they don't already exist.
        let apiURL = URL(string: "https://api.revenuecat.com/v1/subscribers/\(id)")!
        
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(RevenueCatManager.apiKeyV1)", forHTTPHeaderField: "Authorization")
        
        let response = try await self.send(request, expecting: GetSubscriberResponse.self, dateStrategy: .iso8601)
        let name = response.subscriber.subscriber_attributes?[.name]?.value
        
        let user = User(id: id, name: name)
        return user
    }
}

@available(iOS 17.5, *)
private extension RevenueCatManager
{
    @available(iOS 17.5, *)
    func send<T: Decodable>(_ request: URLRequest, expecting: T.Type, dateStrategy: JSONDecoder.DateDecodingStrategy = .millisecondsSince1970) async throws -> T
    {
        guard let url = request.url else { throw URLError(.badURL) }
        
        while true
        {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            guard let httpResponse = urlResponse as? HTTPURLResponse else { throw URLError(.badServerResponse, userInfo: [NSURLErrorKey: url, NSURLErrorFailingURLErrorKey: url]) }
            
            if httpResponse.statusCode == 429
            {
                // Rate Limit Exceeded
                // https://www.revenuecat.com/docs/api-v2/rate-limit
                
                if let retryAfterSeconds = httpResponse.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(retryAfterSeconds), seconds < 60
                {
                    try await Task.sleep(for: .seconds(seconds))
                    continue
                }
                else
                {
                    throw URLError(.resourceUnavailable, userInfo: [NSURLErrorKey: url, NSURLErrorFailingURLErrorKey: url])
                }
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else { throw URLError(.badServerResponse, userInfo: [NSURLErrorKey: url, NSURLErrorFailingURLErrorKey: url]) }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = dateStrategy
            
            let response = try decoder.decode(T.self, from: data)
            return response
        }
    }
}
