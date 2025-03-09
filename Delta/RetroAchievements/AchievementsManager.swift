//
//  AchievementsManager.swift
//  Delta
//
//  Created by Riley Testut on 3/3/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import rcheevos

extension AchievementsManager
{
    struct Account
    {
        var username: String
        var displayName: String
    }
    
    final class UserData
    {
        var continuation: CheckedContinuation<Void, Error>?
        
        init(continuation: CheckedContinuation<Void, Error>? = nil)
        {
            self.continuation = continuation
        }
    }
}

final class AchievementsManager
{
    static let shared = AchievementsManager()
    
    private(set) var account: Account?
    
    private let session: URLSession
    private let authClient: OpaquePointer

    private init()
    {
        // TODO: Finalize version format.
        let deltaVersion: String = if let version = Bundle.main.object(forInfoDictionaryKey: "DLTAVersion") as? String {
            version
        } else if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            version
        } else {
            "1"
        }
        
        let userAgent = "Delta/\(deltaVersion)"
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        self.session = URLSession(configuration: .default)
        
        self.authClient = rc_client_create({ address, buffer, numberOfBytes, client in
            // No need to read memory for authentication.
            return 0
        }, { request, callback, callbackData, client in
            AchievementsManager.send(request: request, callback: callback, callbackData: callbackData, client: client)
        })
        
        rc_client_enable_logging(self.authClient, Int32(RC_CLIENT_LOG_LEVEL_VERBOSE)) { message, client in
            AchievementsManager.log(message: message, client: client)
        }
    }
}

extension AchievementsManager
{
    @discardableResult
    func authenticate(username: String, password: String) async throws -> Account
    {
        let userData = UnsafeMutablePointer<UserData>.allocate(capacity: 1)
        
        try await withCheckedThrowingContinuation { continuation in
            userData.initialize(to: UserData(continuation: continuation))
            
            username.withCString { rawUsername in
                password.withCString { rawPassword in
                    _ = rc_client_begin_login_with_password(self.authClient, rawUsername, rawPassword, { result, errorMessage, client, userData in
                        AchievementsManager.authCallback(result: result, errorMessage: errorMessage, client: client, userData: userData)
                    }, userData)
                }
            }
        }
        
        userData.deallocate()
        
        let account = self.account!
        return account
    }
    
    func authenticateInBackground()
    {
        guard let username = Keychain.shared.retroAchievementsUsername, let token = Keychain.shared.retroAchievementsAuthToken else { return }
        
        username.withCString { rawUsername in
            token.withCString { rawToken in
                _ = rc_client_begin_login_with_token(self.authClient, rawUsername, rawToken, { result, errorMessage, client, userData in
                    AchievementsManager.authCallback(result: result, errorMessage: errorMessage, client: client, userData: userData)
                }, nil)
            }
        }
    }
    
    private static func authCallback(result: Int32, errorMessage: UnsafePointer<CChar>?, client: OpaquePointer!, userData: UnsafeMutableRawPointer?)
    {
        let userData = userData?.assumingMemoryBound(to: UserData.self).pointee
        
        if result == RC_OK, let info = rc_client_get_user_info(client)?.pointee
        {
            let username = String(cString: info.username)
            let token = String(cString: info.token)
            let displayName = String(cString: info.display_name)
            
            Keychain.shared.retroAchievementsUsername = username
            Keychain.shared.retroAchievementsAuthToken = token
            
            Logger.achievements.info("Successfully authenticated RetroAchievements user \(username) (\(displayName))")
            
            let account = Account(username: username, displayName: displayName)
            AchievementsManager.shared.account = account
            
            userData?.continuation?.resume()
        }
        else
        {
            let errorMessage = errorMessage.map { String(cString: $0) }
            Logger.achievements.error("Failed to authenticate RetroAchievements user. \(errorMessage ?? "")")
            
            AchievementsManager.shared.account = nil
            
            let error = AchievementsError(errorCode: Int(result), message: errorMessage)
            userData?.continuation?.resume(throwing: error)
        }
    }
    
    func signOut()
    {
        self.account = nil
        
        Keychain.shared.retroAchievementsUsername = nil
        Keychain.shared.retroAchievementsAuthToken = nil
    }
}

extension AchievementsManager
{
    static func send(request: UnsafePointer<rc_api_request_t>!, callback: rc_client_server_callback_t!, callbackData: UnsafeMutableRawPointer?, client: OpaquePointer!)
    {
        guard let rawRequest = request?.pointee, let urlString = rawRequest.url else { return }
        
        guard let requestURL = URL(string: String(cString: urlString)) else {
            Logger.achievements.error("Failed to create request URL for request. URL: \(String(cString: urlString), privacy: .public)")
            return
        }
        
        var request = URLRequest(url: requestURL)
        if let postBody = rawRequest.post_data
        {
            let body = String(cString: postBody)
            request.httpBody = body.data(using: .utf8)
            
            // If postBody != nil, send POST request.
            request.httpMethod = "POST"
        }
        
        Task<Void, Never> {
            var serverResponse = rc_api_server_response_t()
            let bodyData: Data
            
            do
            {
                let (data, response) = try await AchievementsManager.shared.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                
                serverResponse.http_status_code = Int32(httpResponse.statusCode)
                bodyData = data
            }
            catch
            {
                Logger.achievements.error("Failed to send RA request. \(error.localizedDescription, privacy: .public)")
                
                // Signal to RA the error is recoverable.
                // TODO: Do we want to return this for all errors?
                serverResponse.http_status_code = Int32(RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR)
                
                bodyData = error.localizedDescription.data(using: .utf8)!
            }
            
            bodyData.withUnsafeBytes { unsafeBytes in
                let bytes = unsafeBytes.bindMemory(to: CChar.self).baseAddress
                serverResponse.body = bytes
                serverResponse.body_length = bodyData.count
                callback(&serverResponse, callbackData)
            }
        }
    }

    static func log(message: UnsafePointer<CChar>!, client: OpaquePointer!)
    {
        let log = String(cString: message)
        Logger.achievements.info("\(log, privacy: .public)")
    }
}

