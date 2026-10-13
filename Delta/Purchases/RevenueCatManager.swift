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
    
    struct ProductID: RawRepresentable, Codable, Hashable
    {
        static let level1 = ProductID(rawValue: "delta_level1_500_month")
        
        let rawValue: String
    }
    
    struct IAPSubscription: Identifiable, Hashable
    {
        var id: ProductID
        
        var title: String
        
        var price: Decimal
        var currency: String?
        
        var localizedPriceString: String
        
        fileprivate var storeProduct: StoreProduct
        
        init(_ storeProduct: StoreProduct)
        {
            self.id = ProductID(rawValue: storeProduct.productIdentifier)
            
            self.title = storeProduct.localizedTitle
            self.price = storeProduct.price
            self.currency = storeProduct.currencyCode
            self.localizedPriceString = storeProduct.localizedPriceString
            
            self.storeProduct = storeProduct
        }
    }
    
    enum Subscription: Identifiable
    {
        case level1
        
        var id: Self {
            return self
        }
        
        var title: String {
            switch self
            {
            case .level1: return String(localized: "Delta Patron")
            }
        }
        
        var productID: ProductID {
            switch self
            {
            case .level1: return .level1
            }
        }
    }
}

private extension RevenueCatManager
{
    private struct Tokens: Decodable
    {
        var projectID: String
        var clientPublicKey: String
        var clientSecretV1: String
        var clientSecretV2: String
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

@MainActor
class RevenueCatManager: NSObject
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
    
    var activeSubscription: Subscription? {
        guard let activeProductIDs = self.customerInfo?.activeSubscriptions else { return nil }

        let subscription = [Subscription.level1].first { subscription in
            activeProductIDs.contains(subscription.productID.rawValue)
        }
        return subscription
    }

    private let baseURL = URL(string: "https://api.revenuecat.com")!
    
    private let projectID: String
    private let clientPublicKey: String
    private let clientSecretV1: String
    private let clientSecretV2: String
    
    private override init()
    {
        let fileURL = Bundle.main.url(forResource: "RevenueCatAPI", withExtension: "plist")!
        
        do
        {
            let data = try Data(contentsOf: fileURL)
            
            let tokens = try PropertyListDecoder().decode(Tokens.self, from: data)
            self.projectID = tokens.projectID
            self.clientPublicKey = tokens.clientPublicKey
            self.clientSecretV1 = tokens.clientSecretV1
            self.clientSecretV2 = tokens.clientSecretV2
            
            if self.projectID.isEmpty || self.clientPublicKey.isEmpty || self.clientSecretV1.isEmpty || self.clientSecretV2.isEmpty
            {
                Logger.main.error("RevenueCatAPI.plist is missing required API keys. Please provide your own API keys to use RevenueCat functionality.")
            }
        }
        catch
        {
            Logger.main.error("Failed to load RevenueCatAPI tokens. \(error.localizedDescription, privacy: .public)")
            
            self.projectID = ""
            self.clientPublicKey = ""
            self.clientSecretV1 = ""
            self.clientSecretV2 = ""
        }
        
        super.init()
        
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        
        // Use anonymous user IDs.
        Purchases.configure(withAPIKey: self.clientPublicKey)
        Purchases.shared.delegate = self
    }
    
    func start() async throws
    {
        guard !self.isStarted else { return }
        self.isStarted = true
        
        if PurchaseManager.shared.supportsInAppPurchase
        {
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
                        case .level1: try await self.purchase(.level1)
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

extension RevenueCatManager
{
    func fetchSubscriptions() async -> [IAPSubscription]
    {
        let products = await withCheckedContinuation { (continuation: CheckedContinuation<[StoreProduct], Never>) in
            Purchases.shared.getProducts([Subscription.level1].map { $0.productID.rawValue }) { products in
                continuation.resume(returning: products)
            }
        }
        
        let subscriptions = products.compactMap(IAPSubscription.init)
        return subscriptions
    }
    
    func fetch(_ subscription: Subscription) async -> IAPSubscription?
    {
        let product = await withCheckedContinuation { (continuation: CheckedContinuation<StoreProduct?, Never>) in
            Purchases.shared.getProducts([subscription.productID.rawValue]) { products in
                continuation.resume(returning: products.first)
            }
        }
        
        guard let product else { return nil }
        
        let subscription = IAPSubscription(product)
        return subscription
    }
    
    func purchase(_ subscription: IAPSubscription) async throws
    {
        do
        {
            let (_, customerInfo, isCancelled) = try await Purchases.shared.purchase(product: subscription.storeProduct)
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

extension RevenueCatManager
{
    @discardableResult
    func fetchFriendZoneUsers() async throws -> [User]
    {
        let apiURL = URL(string: "https://api.revenuecat.com/v2/projects/\(self.projectID)/customers?limit=1000")!
        
        var userIDs: Set<String> = []
        
        func fetchPatrons(url: URL) async throws
        {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(self.clientSecretV2)", forHTTPHeaderField: "Authorization")
            
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
        request.setValue("Bearer \(self.clientSecretV1)", forHTTPHeaderField: "Authorization")
        
        let response = try await self.send(request, expecting: GetSubscriberResponse.self, dateStrategy: .iso8601)
        let name = response.subscriber.subscriber_attributes?[.name]?.value
        
        let user = User(id: id, name: name)
        return user
    }
}

private extension RevenueCatManager
{
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

extension RevenueCatManager: PurchasesDelegate
{
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo)
    {
        Task<Void, Never> { @MainActor in
            self.customerInfo = customerInfo
            NotificationCenter.default.post(name: RevenueCatManager.didUpdateCustomerInfoNotification, object: customerInfo)
        }
    }
}
