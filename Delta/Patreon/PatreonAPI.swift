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

private let clientID = "ZMx0EGUWe4TVWYXNZZwK_fbIK5jHFVWoUf1Qb-sqNXmT-YzAGwDPxxq7ak3_W5Q2"
private let clientSecret = "1hktsZB89QyN69cB4R0tu55R4TCPQGXxvebYUUh7Y-5TLSnRswuxs6OUjdJ74IJt"

enum PatreonAPIError: LocalizedError
{
    case unknown
    case notAuthenticated
    case invalidAccessToken
    
    var failureReason: String? {
        switch self
        {
        case .unknown: return NSLocalizedString("An unknown error occurred.", comment: "")
        case .notAuthenticated: return NSLocalizedString("No connected Patreon account.", comment: "")
        case .invalidAccessToken: return NSLocalizedString("Invalid access token.", comment: "")
        }
    }
}

extension PatreonAPI
{
    static let altstoreCampaignID = "2863968"
    
    typealias FetchAccountResponse = Response<UserAccountResponse>
    typealias FriendZonePatronsResponse = Response<[PatronResponse]>
    
    enum AuthorizationType
    {
        case none
        case user
        case creator
    }
}

public class PatreonAPI: NSObject
{
    public static let shared = PatreonAPI()
    
    public var isAuthenticated: Bool {
        return Keychain.shared.patreonAccessToken != nil
    }
    
    private var authenticationSession: ASWebAuthenticationSession?
    private weak var presentingViewController: UIViewController?
    
    private let session = URLSession(configuration: .ephemeral)
    private let baseURL = URL(string: "https://www.patreon.com/")!
    
    private override init()
    {
        super.init()
    }
}

public extension PatreonAPI
{
    func authenticate(presentingViewController: UIViewController, completion: @escaping (Result<PatreonAccount, Swift.Error>) -> Void)
    {
        var components = URLComponents(string: "/oauth2/authorize")!
        components.queryItems = [URLQueryItem(name: "response_type", value: "code"),
                                 URLQueryItem(name: "client_id", value: clientID),
                                 URLQueryItem(name: "redirect_uri", value: "https://rileytestut.com/patreon/altstore")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        
        self.authenticationSession = ASWebAuthenticationSession(url: requestURL, callbackURLScheme: "altstore") { (callbackURL, error) in
            do
            {
                guard let callbackURL = callbackURL else { throw error ?? URLError(.badURL) }
                                
                guard
                    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let codeQueryItem = components.queryItems?.first(where: { $0.name == "code" }),
                    let code = codeQueryItem.value
                else { throw PatreonAPIError.unknown }
                
                self.fetchAccessToken(oauthCode: code) { (result) in
                    switch result
                    {
                    case .failure(let error): completion(.failure(error))
                    case .success((let accessToken, let refreshToken)):
                        Keychain.shared.patreonAccessToken = accessToken
                        Keychain.shared.patreonRefreshToken = refreshToken
                        
                        self.fetchAccount(completion: completion)
                    }
                }
            }
            catch ASWebAuthenticationSessionError.canceledLogin
            {
                completion(.failure(CancellationError()))
            }
            catch
            {
                completion(.failure(error))
            }
            
            self.presentingViewController = nil
        }
        
        self.presentingViewController = presentingViewController
        
        self.authenticationSession?.presentationContextProvider = self
        self.authenticationSession?.start()
    }
    
    func fetchAccount(completion: @escaping (Result<PatreonAccount, Swift.Error>) -> Void)
    {
        var components = URLComponents(string: "/api/oauth2/v2/identity")!
        components.queryItems = [URLQueryItem(name: "include", value: "memberships.campaign.tiers,memberships.currently_entitled_tiers.benefits"),
                                 URLQueryItem(name: "fields[user]", value: "first_name,full_name"),
                                 URLQueryItem(name: "fields[tier]", value: "title,amount_cents"),
                                 URLQueryItem(name: "fields[benefit]", value: "title"),
                                 URLQueryItem(name: "fields[campaign]", value: "url"),
                                 URLQueryItem(name: "fields[member]", value: "full_name,patron_status,currently_entitled_amount_cents")]
        
        let requestURL = components.url(relativeTo: self.baseURL)!
        let request = URLRequest(url: requestURL)
        
        self.send(request, authorizationType: .user) { (result: Result<FetchAccountResponse, Swift.Error>) in
            switch result
            {
            case .failure(PatreonAPIError.notAuthenticated):
                self.signOut() { (result) in
                    completion(.failure(PatreonAPIError.notAuthenticated))
                }
                
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
                catch let error as NSError
                {
                    let localizedDescription = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
                    Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                    completion(.failure(error))
                }
                
            case .failure(let error as NSError):
                let localizedDescription = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
                Logger.main.error("Failed to fetch Patreon account. \(localizedDescription, privacy: .public)")
                completion(.failure(error))
                
            case .success(let response):
                let account = PatreonAPI.UserAccount(response: response.data, including: response.included)
                
                DatabaseManager.shared.performBackgroundTask { (context) in
                    let account = PatreonAccount(account: account, context: context)
                    Keychain.shared.patreonAccountID = account.identifier
                    completion(.success(account))
                }
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
                
                completion(.success(()))
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
            }
            catch
            {
                print("Failed to fetch Patreon account.", error)
            }
        }
    }
}

private extension PatreonAPI
{
    func fetchAccessToken(oauthCode: String, completion: @escaping (Result<(String, String), Swift.Error>) -> Void)
    {
        let encodedRedirectURI = ("https://rileytestut.com/patreon/altstore" as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let encodedOauthCode = (oauthCode as NSString).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let body = "code=\(encodedOauthCode)&grant_type=authorization_code&client_id=\(clientID)&client_secret=\(clientSecret)&redirect_uri=\(encodedRedirectURI)"
        
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
                                 URLQueryItem(name: "client_id", value: clientID),
                                 URLQueryItem(name: "client_secret", value: clientSecret)]
        
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
    
    func send<ResponseType: Decodable>(_ request: URLRequest, authorizationType: AuthorizationType, completion: @escaping (Result<ResponseType, Swift.Error>) -> Void)
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
        
        let task = self.session.dataTask(with: request) { (data, response, error) in
            do
            {
                guard let data else { throw error ?? URLError(.badServerResponse) }
                                
                if let response = response as? HTTPURLResponse, response.statusCode == 401
                {
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
}

extension PatreonAPI: ASWebAuthenticationPresentationContextProviding
{
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
    {
        return self.presentingViewController?.view.window ?? UIWindow()
    }
}
