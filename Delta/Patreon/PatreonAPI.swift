//
//  PatreonAPI.swift
//  AltStore
//
//  Created by Riley Testut on 8/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AuthenticationServices
import CoreData
import OSLog
import SafariServices

enum PatreonAPIError: LocalizedError
{
    case unknown
    case notAuthenticated
    case invalidAccessToken
    case rateLimitExceeded
    case pledgeInactive
    
    var failureReason: String? {
        switch self
        {
        case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
        case .notAuthenticated: return NSLocalizedString("No connected Patreon account.", comment: "")
        case .invalidAccessToken: return NSLocalizedString("Invalid access token.", comment: "")
        case .rateLimitExceeded: return NSLocalizedString("The Patreon API rate limit has been exceeded.", comment: "")
        case .pledgeInactive: return NSLocalizedString("Your pledge is no longer active.", comment: "")
        }
    }
}

extension PatreonAPI
{
    static let altstoreCampaignID = "2863968"
    
    static let operationDidFinish: Notification.Name = .init("com.rileytestut.Delta.PatreonOperationDidFinish")
    
    typealias FetchAccountResponse = Response<UserAccountResponse>
    typealias FriendZonePatronsResponse = Response<[PatronResponse]>
    typealias FetchCampaignResponse = Response<CampaignResponse>
    
    enum AuthorizationType
    {
        case none
        case user
        case creator
    }
    
    private struct Tokens: Decodable
    {
        var clientID: String
        var clientSecret: String
    }
}

public class PatreonAPI: NSObject
{
    public static let shared = PatreonAPI()
    
    public var isAuthenticated: Bool {
        return Keychain.shared.patreonAccessToken != nil
    }
    
    private let session = URLSession(configuration: .ephemeral)
    private let baseURL = URL(string: "https://www.patreon.com/")!
    
    private let clientID: String
    private let clientSecret: String
    
    private override init()
    {
        let fileURL = Bundle.main.url(forResource: "PatreonAPI", withExtension: "plist")!
        
        do
        {
            let data = try Data(contentsOf: fileURL)
            
            let tokens = try PropertyListDecoder().decode(Tokens.self, from: data)
            self.clientID = tokens.clientID
            self.clientSecret = tokens.clientSecret
            
            if self.clientID.isEmpty || self.clientSecret.isEmpty
            {
                Logger.main.error("PatreonAPI.plist is missing clientID and/or clientSecret. Please provide your own API keys to use Patreon functionality.")
            }
        }
        catch
        {
            Logger.main.error("Failed to load PatreonAPI tokens. \(error.localizedDescription, privacy: .public)")
            
            self.clientID = ""
            self.clientSecret = ""
        }
        
        super.init()
    }
}

public extension PatreonAPI
{
    @MainActor @discardableResult
    func authenticate(presentingViewController: UIViewController) async throws -> PatreonAccount
    {
        var components = URLComponents(string: "/oauth2/authorize")!
        components.queryItems = [URLQueryItem(name: "response_type", value: "code"),
                                 URLQueryItem(name: "client_id", value: self.clientID),
                                 URLQueryItem(name: "redirect_uri", value: "https://rileytestut.com/patreon/delta")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        let safariViewController = SFSafariViewController(url: requestURL)
        safariViewController.delegate = self
        presentingViewController.present(safariViewController, animated: true)
        
        defer {
            safariViewController.dismiss(animated: true)
        }
        
        var callbackURL: URL?
        
        // Wait for first notification
        for await notification in NotificationCenter.default.notifications(named: PatreonAPI.operationDidFinish)
        {
            callbackURL = notification.userInfo?["url"] as? URL
            break
        }
        
        guard let callbackURL else { throw CancellationError() }
        
        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let codeQueryItem = components.queryItems?.first(where: { $0.name == "code" }),
            let code = codeQueryItem.value
        else { throw PatreonAPIError.unknown }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.fetchAccessToken(oauthCode: code) { (result) in
                switch result
                {
                case .failure(let error): continuation.resume(throwing: error)
                case .success((let accessToken, let refreshToken)):
                    Keychain.shared.patreonAccessToken = accessToken
                    Keychain.shared.patreonRefreshToken = refreshToken
                    
                    self.fetchAccount { result in
                        do
                        {
                            let patreonAccount = try result.get()
                            try patreonAccount.managedObjectContext?.save()
                            
                            continuation.resume() // We'll re-fetch PatreonAccount from view context
                        }
                        catch
                        {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
        
        guard let patreonAccount = DatabaseManager.shared.patreonAccount() else { throw PatreonAPIError.unknown }
        return patreonAccount
    }
    
    func fetchAccount(completion: @escaping (Result<PatreonAccount, Swift.Error>) -> Void)
    {
        Task<Void, Never> {
            do
            {
                let userAccount = try await self.fetchUserAccount()
                
                await DatabaseManager.shared.performBackgroundTask { (context) in
                    let account = PatreonAccount(account: userAccount, context: context)
                    Keychain.shared.patreonAccountID = account.identifier
                    completion(.success(account))
                }
            }
            catch PatreonAPIError.notAuthenticated
            {
                self.signOut() { (result) in
                    completion(.failure(PatreonAPIError.notAuthenticated))
                }
            }
            catch
            {
                completion(.failure(error))
            }
        }
    }
    
    func fetchUserAccount() async throws -> PatreonAPI.UserAccount
    {
        var components = URLComponents(string: "/api/oauth2/v2/identity")!
        components.queryItems = [URLQueryItem(name: "include", value: "memberships.campaign.tiers,memberships.currently_entitled_tiers.benefits,memberships.pledge_history"),
                                 URLQueryItem(name: "fields[user]", value: "first_name,full_name"),
                                 URLQueryItem(name: "fields[tier]", value: "title,amount_cents"),
                                 URLQueryItem(name: "fields[benefit]", value: "title"),
                                 URLQueryItem(name: "fields[campaign]", value: "url"),
                                 URLQueryItem(name: "fields[pledge-event]", value: "amount_cents,currency_code,payment_status"),
                                 URLQueryItem(name: "fields[member]", value: "full_name,patron_status,currently_entitled_amount_cents,campaign_lifetime_support_cents")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        let request = URLRequest(url: requestURL)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserAccount, Error>) in
            self.send(request, authorizationType: .user) { (result: Result<FetchAccountResponse, Swift.Error>) in
                switch result
                {
                case .failure(let error as DecodingError):
                    do
                    {
                        let nsError = error as NSError
                        guard let codingPath = nsError.userInfo["NSCodingPath"] as? [CodingKey] else { throw error }
                        
                        let rawComponents = codingPath.map { $0.intValue?.description ?? $0.stringValue }
                        let pathDescription = rawComponents.joined(separator: " > ")
                                            
                        let localizedDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String ?? nsError.localizedDescription
                        let debugDescription = localizedDescription + " Path: " + pathDescription
                        
                        var userInfo = nsError.userInfo
                        userInfo[NSDebugDescriptionErrorKey] = debugDescription
                        throw NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
                    }
                    catch
                    {
                        let nsError =  error as NSError
                        let localizedDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String ?? nsError.localizedDescription
                        Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                        continuation.resume(throwing: error)
                    }
                    
                case .failure(let error):
                    let nsError =  error as NSError
                    let localizedDescription = nsError.userInfo[NSDebugDescriptionErrorKey] as? String ?? nsError.localizedDescription
                    Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                    
                case .success(let response):
                    let account = PatreonAPI.UserAccount(response: response.data, including: response.included)
                    continuation.resume(returning: account)
                }
            }
        }
    }
    
    func fetchPatrons(completion: @escaping (Result<[Patron], Swift.Error>) -> Void)
    {
        var components = URLComponents(string: "/api/oauth2/v2/campaigns/\(PatreonAPI.altstoreCampaignID)/members")!
        components.queryItems = [URLQueryItem(name: "include", value: "currently_entitled_tiers,currently_entitled_tiers.benefits"),
                                 URLQueryItem(name: "fields[tier]", value: "title,amount_cents"),
                                 URLQueryItem(name: "fields[member]", value: "full_name,patron_status,currently_entitled_amount_cents,campaign_lifetime_support_cents"),
                                 URLQueryItem(name: "page[size]", value: "1000")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        var allPatrons = [Patron]()
        
        func fetchPatrons(url: URL)
        {
            let request = URLRequest(url: url)
            
            self.send(request, authorizationType: .creator) { (result: Result<FriendZonePatronsResponse, Swift.Error>) in
                switch result
                {
                case .failure(let error): completion(.failure(error))
                case .success(let patronsResponse):
                    let patrons = patronsResponse.data.map { (response) -> Patron in
                        let patron = Patron(response: response, including: patronsResponse.included)
                        return patron
                    }.filter { $0.benefits.contains(where: { $0.identifier == .credits }) }
                    
                    allPatrons.append(contentsOf: patrons)
                    
                    if let nextURL = patronsResponse.links?["next"]
                    {
                        fetchPatrons(url: nextURL)
                    }
                    else
                    {
                        completion(.success(allPatrons))
                    }
                }
            }
        }
        
        fetchPatrons(url: requestURL)
    }
    
    func signOut() async throws
    {
        try await withCheckedThrowingContinuation { continuation in
            self.signOut { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func signOut(completion: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        DatabaseManager.shared.performBackgroundTask { (context) in
            do
            {
                let fetchRequest = PatreonAccount.fetchRequest()
                fetchRequest.returnsObjectsAsFaults = true
                
                let accounts = try context.fetch(fetchRequest)
                accounts.forEach(context.delete(_:))
                
                try context.save()
                
                Keychain.shared.patreonAccessToken = nil
                Keychain.shared.patreonRefreshToken = nil
                Keychain.shared.patreonAccountID = nil
                
                Task<Void, Never> {
                    await PurchaseManager.shared.update()
                    await SFSafariViewController.DataStore.default.clearWebsiteData()
                    
                    completion(.success(()))
                }
            }
            catch
            {
                completion(.failure(error))
            }
        }
    }
    
    func refreshPatreonAccount()
    {
        guard PatreonAPI.shared.isAuthenticated else { return }
        
        PatreonAPI.shared.fetchAccount { (result: Result<PatreonAccount, Swift.Error>) in
            do
            {
                let account = try result.get()
                try account.managedObjectContext?.save()
                
                Task<Void, Never> {
                    await PurchaseManager.shared.update()
                }
            }
            catch
            {
                print("Failed to fetch Patreon account.", error)
            }
        }
    }
}

extension PatreonAPI
{
    func fetchTiers() async throws -> [Tier]
    {
        var components = URLComponents(string: "/api/oauth2/v2/campaigns/\(PatreonAPI.altstoreCampaignID)")!
        components.queryItems = [
            URLQueryItem(name: "include", value: "tiers"),
            URLQueryItem(name: "fields[campaign]", value: "url"),
            URLQueryItem(name: "fields[tier]", value: "title,amount_cents,patron_count,url"),
            URLQueryItem(name: "fields[benefit]", value: "title"),
        ]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        let request = URLRequest(url: requestURL)
        
        struct Response: Decodable
        {
            var access_token: String
            var refresh_token: String
        }
        
        let response = try await withCheckedThrowingContinuation { continuation in
            self.send(request, authorizationType: .creator) { (result: Result<FetchCampaignResponse, Swift.Error>) in
                continuation.resume(with: result)
            }
        }
        
        let campaign = Campaign(response: response.data, including: response.included)
        return campaign.tiers ?? []
    }
    
    @MainActor
    func join(_ tier: Tier, presentingViewController: UIViewController) async throws -> (UserAccount, Patron, isNewPatron: Bool)
    {
        if DatabaseManager.shared.patreonAccount() == nil
        {
            _ = try await self.authenticate(presentingViewController: presentingViewController)
        }
        
        // At this point, we know user is authenticated.
        
        do
        {
            // Make sure user is not already a member of this tier.
            let account = try await self.fetchUserAccount()
            
            if let altstorePledge = account.pledges?.first(where: { $0.campaign?.identifier == Campaign.rileyShaneID })
            {
                // User is a patron, check if they already belong to this tier.
                guard !altstorePledge.tiers.contains(where: { $0.identifier == tier.identifier }) else {
                    // Already a patron at this tier, so we can return false bc we are not a NEW patron.
                    // TODO: Handle expired patrons
                    return (account, altstorePledge, false)
                }
            }
        }
        
        // At this point, we know user is authenticated but NOT an active patron.
        
        let joinTierURL = URL(string: "https://patreon.com/checkout/rileyshane?rid=\(tier.identifier)")!
        
        if let region = PurchaseManager.shared.externalPurchaseRegion, region.supportsInAppWebView
        {
            let safariViewController = SFSafariViewController(url: joinTierURL)
            safariViewController.delegate = self
            presentingViewController.present(safariViewController, animated: true)
            
            // Wait for first notification
            for await _ in NotificationCenter.default.notifications(named: PatreonAPI.operationDidFinish)
            {
                break
            }
        }
        else
        {
            try await withCheckedThrowingContinuation { continuation in
                UIApplication.shared.open(joinTierURL, options: [:]) { success in
                    if success
                    {
                        continuation.resume()
                    }
                    else
                    {
                        continuation.resume(throwing: PatreonAPIError.unknown)
                    }
                }
            }
            
            // Wait until user returns to foreground, and then check if they became a patron.
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification)
            {
                break
            }
        }
        
        let account = try await self.fetchUserAccount()
        
        guard let altstorePledge = account.pledges?.first(where: { $0.campaign?.identifier == Campaign.rileyShaneID }) else {
            // User is not an active patron, so assume they cancelled purchase flow.
            throw CancellationError()
        }
        
        guard altstorePledge.status == .active || altstorePledge.status == .unknown else { throw PatreonAPIError.pledgeInactive }
        
        if altstorePledge.tiers.contains(where: { $0.identifier == tier.identifier })
        {
            // We've joined the tier!
            return (account, altstorePledge, true)
        }
        else
        {
            // We did not join this tier, assume they cancelled purchase flow.
            throw CancellationError()
        }
    }
}

private extension PatreonAPI
{
    func fetchAccessToken(oauthCode: String, completion: @escaping (Result<(String, String), Swift.Error>) -> Void)
    {
        let encodedRedirectURI = ("https://rileytestut.com/patreon/delta" as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let encodedOauthCode = (oauthCode as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let body = "code=\(encodedOauthCode)&grant_type=authorization_code&client_id=\(self.clientID)&client_secret=\(self.clientSecret)&redirect_uri=\(encodedRedirectURI)"
        
        let requestURL = URL(string: "/api/oauth2/token", relativeTo: self.baseURL)!
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        struct Response: Decodable
        {
            var access_token: String
            var refresh_token: String
        }
        
        self.send(request, authorizationType: .none) { (result: Result<Response, Swift.Error>) in
            switch result
            {
            case .failure(let error): completion(.failure(error))
            case .success(let response): completion(.success((response.access_token, response.refresh_token)))
            }
        }
    }
    
    func refreshAccessToken(completion: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        guard let refreshToken = Keychain.shared.patreonRefreshToken else { return }
        
        var components = URLComponents(string: "/api/oauth2/token")!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token"),
                                 URLQueryItem(name: "refresh_token", value: refreshToken),
                                 URLQueryItem(name: "client_id", value: self.clientID),
                                 URLQueryItem(name: "client_secret", value: self.clientSecret)]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        
        struct Response: Decodable
        {
            var access_token: String
            var refresh_token: String
        }
        
        self.send(request, authorizationType: .none) { (result: Result<Response, Swift.Error>) in
            switch result
            {
            case .failure(let error): completion(.failure(error))
            case .success(let response):
                Keychain.shared.patreonAccessToken = response.access_token
                Keychain.shared.patreonRefreshToken = response.refresh_token
                
                completion(.success(()))
            }
        }
    }
    
    func send<ResponseType: Decodable & SendableMetatype>(_ request: URLRequest, authorizationType: AuthorizationType, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void)
    {
        var request = request
        
        switch authorizationType
        {
        case .none: break
        case .creator:
            guard let creatorAccessToken = Keychain.shared.patreonCreatorAccessToken else { return completion(.failure(PatreonAPIError.invalidAccessToken)) }
            request.setValue("Bearer " + creatorAccessToken, forHTTPHeaderField: "Authorization")
            
        case .user:
            guard let accessToken = Keychain.shared.patreonAccessToken else { return completion(.failure(PatreonAPIError.notAuthenticated)) }
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        }
        
        func send(retryDelay: TimeInterval = 1.0, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void)
        {
            let task = self.session.dataTask(with: request) { (data, response, error) in
                do
                {
                    guard let data else { throw error! }
                    
                    if let response = response as? HTTPURLResponse
                    {
                        switch response.statusCode
                        {
                        case 401:
                            // Unauthorized
                            switch authorizationType
                            {
                            case .creator: completion(.failure(PatreonAPIError.invalidAccessToken))
                            case .none: completion(.failure(PatreonAPIError.notAuthenticated))
                            case .user:
                                self.refreshAccessToken() { (result) in
                                    switch result
                                    {
                                    case .failure(let error): completion(.failure(error))
                                    case .success: self.send(request, authorizationType: authorizationType, completion: completion)
                                    }
                                }
                            }
                            
                            return
                            
                        case 429:
                            // Rate Limited
                            let rateLimitDelay: TimeInterval
                            if let delayString = response.value(forHTTPHeaderField: "Retry-After"), let delay = TimeInterval(delayString)
                            {
                                rateLimitDelay = delay
                            }
                            else
                            {
                                rateLimitDelay = retryDelay
                            }
                            
                            guard rateLimitDelay <= 60 else {
                                // Assume request failed.
                                return completion(.failure(PatreonAPIError.rateLimitExceeded))
                            }
                            
                            Logger.main.error("Patreon API rate limit exceeded. Retrying request after delay: \(rateLimitDelay)")
                            
                            DispatchQueue.global().asyncAfter(deadline: .now() + Double(rateLimitDelay)) {
                                // Double previous delay, in case Patreon API doesn't return Retry-After header.
                                send(retryDelay: rateLimitDelay * 2, completion: completion)
                            }
                            
                            return
                            
                        default: break
                        }
                    }
                    
                    let response = try JSONDecoder().decode(ResponseType.self, from: data)
                    completion(.success(response))
                }
                catch let error
                {
                    completion(.failure(error))
                }
            }
            
            task.resume()
        }
        
        send(completion: completion)
    }
}

extension PatreonAPI: SFSafariViewControllerDelegate
{
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController)
    {
        NotificationCenter.default.post(name: PatreonAPI.operationDidFinish, object: nil)
    }
}
