///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// This is a convenience class for the typical single user case. To use this
/// class, see details in the tutorial at:
/// https://www.dropbox.com/developers/documentation/swift#tutorial
///
/// For information on the available API methods, see the documentation for DropboxClient
open class DropboxClientsManager {
    /// An authorized client. This will be set to nil if unlinked.
    public static var authorizedClient: DropboxClient?

    /// An authorized team client. This will be set to nil if unlinked.
    public static var authorizedTeamClient: DropboxTeamClient?

    /// Sets up access to the Dropbox User API
    static func setupWithOAuthManager(_ appKey: String, oAuthManager: DropboxOAuthManager, transportClient: DropboxTransportClient?) {
        precondition(DropboxOAuthManager.sharedOAuthManager == nil, "Only call `DropboxClientsManager.setupWithAppKey` or `DropboxClientsManager.setupWithTeamAppKey` once")
        DropboxOAuthManager.sharedOAuthManager = oAuthManager

        if let token = DropboxOAuthManager.sharedOAuthManager.getFirstAccessToken() {
            setupAuthorizedClient(token, transportClient:transportClient)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    /// Sets up access to the Dropbox User API
    static func setupWithOAuthManagerMultiUser(_ appKey: String, oAuthManager: DropboxOAuthManager, transportClient: DropboxTransportClient?, tokenUid: String?) {
        precondition(DropboxOAuthManager.sharedOAuthManager == nil, "Only call `DropboxClientsManager.setupWithAppKey` or `DropboxClientsManager.setupWithTeamAppKey` once")
        DropboxOAuthManager.sharedOAuthManager = oAuthManager

        if let token = DropboxOAuthManager.sharedOAuthManager.getAccessToken(tokenUid) {
            setupAuthorizedClient(token, transportClient:transportClient)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    /// Sets up access to the Dropbox Business (Team) API
    static func setupWithOAuthManagerTeam(_ appKey: String, oAuthManager: DropboxOAuthManager, transportClient: DropboxTransportClient?) {
        precondition(DropboxOAuthManager.sharedOAuthManager == nil, "Only call `DropboxClientsManager.setupWithAppKey` or `DropboxClientsManager.setupWithTeamAppKey` once")
        DropboxOAuthManager.sharedOAuthManager = oAuthManager

        if let token = DropboxOAuthManager.sharedOAuthManager.getFirstAccessToken() {
            setupAuthorizedTeamClient(token, transportClient:transportClient)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    /// Sets up access to the Dropbox Business (Team) API in multi-user case
    static func setupWithOAuthManagerMultiUserTeam(_ appKey: String, oAuthManager: DropboxOAuthManager, transportClient: DropboxTransportClient?, tokenUid: String?) {
        precondition(DropboxOAuthManager.sharedOAuthManager == nil, "Only call `DropboxClientsManager.setupWithAppKey` or `DropboxClientsManager.setupWithTeamAppKey` once")
        DropboxOAuthManager.sharedOAuthManager = oAuthManager

        if let token = DropboxOAuthManager.sharedOAuthManager.getAccessToken(tokenUid) {
            setupAuthorizedTeamClient(token, transportClient:transportClient)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    public static func reauthorizeClient(_ tokenUid: String) {
        precondition(DropboxOAuthManager.sharedOAuthManager != nil, "Call `DropboxClientsManager.setupWithAppKey` before calling this method")

        if let token = DropboxOAuthManager.sharedOAuthManager.getAccessToken(tokenUid) {
            setupAuthorizedClient(token, transportClient:nil)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    public static func reauthorizeTeamClient(_ tokenUid: String) {
        precondition(DropboxOAuthManager.sharedOAuthManager != nil, "Call `DropboxClientsManager.setupWithAppKey` before calling this method")

        if let token = DropboxOAuthManager.sharedOAuthManager.getAccessToken(tokenUid) {
            setupAuthorizedTeamClient(token, transportClient:nil)
        }
        Keychain.checkAccessibilityMigrationOneTime
    }

    static func setupAuthorizedClient(_ accessToken: DropboxAccessToken?, transportClient: DropboxTransportClient?) {
        if let accessToken = accessToken {
            if let transportClient = transportClient {
                transportClient.accessToken = accessToken.accessToken
                authorizedClient = DropboxClient(transportClient: transportClient)
            } else {
                authorizedClient = DropboxClient(accessToken: accessToken.accessToken)
            }
        } else {
            if let transportClient = transportClient {
                authorizedClient = DropboxClient(transportClient: transportClient)
            }
        }
    }

    static func setupAuthorizedTeamClient(_ accessToken: DropboxAccessToken?, transportClient: DropboxTransportClient?) {
        if let accessToken = accessToken {
            if let transportClient = transportClient {
                transportClient.accessToken = accessToken.accessToken
                authorizedTeamClient = DropboxTeamClient(transportClient: transportClient)
            } else {
                authorizedTeamClient = DropboxTeamClient(accessToken: accessToken.accessToken)
            }
        } else {
            if let transportClient = transportClient {
                authorizedTeamClient = DropboxTeamClient(transportClient: transportClient)
            }
        }
    }

    /// Handle a redirect and automatically initialize the client and save the token.
    public static func handleRedirectURL(_ url: URL) -> DropboxOAuthResult? {
        precondition(DropboxOAuthManager.sharedOAuthManager != nil, "Call `DropboxClientsManager.setupWithAppKey` before calling this method")
        if let result =  DropboxOAuthManager.sharedOAuthManager.handleRedirectURL(url) {
            switch result {
            case .success(let accessToken):
                DropboxClientsManager.authorizedClient = DropboxClient(accessToken: accessToken.accessToken)
                return result
            case .cancel:
                return result
            case .error:
                return result
            }
        } else {
            return nil
        }
    }

    /// Handle a redirect and automatically initialize the client and save the token.
    public static func handleRedirectURLTeam(_ url: URL) -> DropboxOAuthResult? {
        precondition(DropboxOAuthManager.sharedOAuthManager != nil, "Call `DropboxClientsManager.setupWithTeamAppKey` before calling this method")
        if let result =  DropboxOAuthManager.sharedOAuthManager.handleRedirectURL(url) {
            switch result {
            case .success(let accessToken):
                DropboxClientsManager.authorizedTeamClient = DropboxTeamClient(accessToken: accessToken.accessToken)
                return result
            case .cancel:
                return result
            case .error:
                return result
            }
        } else {
            return nil
        }
    }

    /// Unlink the user.
    public static func unlinkClients() {
        if let oAuthManager = DropboxOAuthManager.sharedOAuthManager {
            _ = oAuthManager.clearStoredAccessTokens()
            resetClients()
        }
    }

    /// Unlink the user.
    public static func resetClients() {
        if DropboxClientsManager.authorizedClient == nil && DropboxClientsManager.authorizedTeamClient == nil {
            // already unlinked
            return
        }

        DropboxClientsManager.authorizedClient = nil
        DropboxClientsManager.authorizedTeamClient = nil
    }
}
