///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import SafariServices
import UIKit
import WebKit

extension DropboxClientsManager {
    public static func authorizeFromController(_ sharedApplication: UIApplication, controller: UIViewController?, openURL: @escaping ((URL) -> Void)) {
        precondition(DropboxOAuthManager.sharedOAuthManager != nil, "Call `DropboxClientsManager.setupWithAppKey` or `DropboxClientsManager.setupWithTeamAppKey` before calling this method")
        let sharedMobileApplication = MobileSharedApplication(sharedApplication: sharedApplication, controller: controller, openURL: openURL)
        MobileSharedApplication.sharedMobileApplication = sharedMobileApplication
        DropboxOAuthManager.sharedOAuthManager.authorizeFromSharedApplication(sharedMobileApplication)
    }

    public static func setupWithAppKey(_ appKey: String, transportClient: DropboxTransportClient? = nil) {
        setupWithOAuthManager(appKey, oAuthManager: DropboxMobileOAuthManager(appKey: appKey), transportClient: transportClient)
    }

    public static func setupWithAppKeyMultiUser(_ appKey: String, transportClient: DropboxTransportClient? = nil, tokenUid: String?) {
        setupWithOAuthManagerMultiUser(appKey, oAuthManager: DropboxMobileOAuthManager(appKey: appKey), transportClient: transportClient, tokenUid: tokenUid)
    }

    public static func setupWithTeamAppKey(_ appKey: String, transportClient: DropboxTransportClient? = nil) {
        setupWithOAuthManagerTeam(appKey, oAuthManager: DropboxMobileOAuthManager(appKey: appKey), transportClient: transportClient)
    }

    public static func setupWithTeamAppKeyMultiUser(_ appKey: String, transportClient: DropboxTransportClient? = nil, tokenUid: String?) {
        setupWithOAuthManagerMultiUserTeam(appKey, oAuthManager: DropboxMobileOAuthManager(appKey: appKey), transportClient: transportClient, tokenUid: tokenUid)
    }
}

open class DropboxMobileOAuthManager: DropboxOAuthManager {
    var dauthRedirectURL: URL
    
    public override init(appKey: String, host: String) {
        self.dauthRedirectURL = URL(string: "db-\(appKey)://1/connect")!
        super.init(appKey: appKey, host:host)
        self.urls.append(self.dauthRedirectURL)
    }
    
    internal override func extractFromUrl(_ url: URL) -> DropboxOAuthResult {
        let result: DropboxOAuthResult
        if url.host == "1" { // dauth
            result = extractfromDAuthURL(url)
        } else {
            result = extractFromRedirectURL(url)
        }
        return result
    }
    
    internal override func checkAndPresentPlatformSpecificAuth(_ sharedApplication: SharedApplication) -> Bool {
        if !self.hasApplicationQueriesSchemes() {
            let message = "DropboxSDK: unable to link; app isn't registered to query for URL schemes dbapi-2 and dbapi-8-emm. Add a dbapi-2 entry and a dbapi-8-emm entry to LSApplicationQueriesSchemes"
            let title = "SwiftyDropbox Error"
            sharedApplication.presentErrorMessage(message, title: title)
            return true
        }
        
        if let scheme = dAuthScheme(sharedApplication) {
            let nonce = UUID().uuidString
            UserDefaults.standard.set(nonce, forKey: kDBLinkNonce)
            UserDefaults.standard.synchronize()
            sharedApplication.presentExternalApp(dAuthURL(scheme, nonce: nonce))
            return true
        }
        return false
    }
    
    open override func handleRedirectURL(_ url: URL) -> DropboxOAuthResult? {
        if let sharedMobileApplication = MobileSharedApplication.sharedMobileApplication {
            sharedMobileApplication.dismissAuthController()
        }
        let result = super.handleRedirectURL(url)
        return result
    }

    fileprivate func dAuthURL(_ scheme: String, nonce: String?) -> URL {
        var components = URLComponents()
        components.scheme =  scheme
        components.host = "1"
        components.path = "/connect"
        
        if let n = nonce {
            let state = "oauth2:\(n)"
            components.queryItems = [
                URLQueryItem(name: "k", value: self.appKey),
                URLQueryItem(name: "s", value: ""),
                URLQueryItem(name: "state", value: state),
            ]
        }
        return components.url!
    }
    
    fileprivate func dAuthScheme(_ sharedApplication: SharedApplication) -> String? {
        if sharedApplication.canPresentExternalApp(dAuthURL("dbapi-2", nonce: nil)) {
            return "dbapi-2"
        } else if sharedApplication.canPresentExternalApp(dAuthURL("dbapi-8-emm", nonce: nil)) {
            return "dbapi-8-emm"
        } else {
            return nil
        }
    }
    
    func extractfromDAuthURL(_ url: URL) -> DropboxOAuthResult {
        switch url.path {
        case "/connect":
            var results = [String: String]()
            let pairs  = url.query?.components(separatedBy: "&") ?? []
            
            for pair in pairs {
                let kv = pair.components(separatedBy: "=")
                results.updateValue(kv[1], forKey: kv[0])
            }
            let state = results["state"]?.components(separatedBy: "%3A") ?? []
            
            let nonce = UserDefaults.standard.object(forKey: kDBLinkNonce) as? String
            if state.count == 2 && state[0] == "oauth2" && state[1] == nonce! {
                let accessToken = results["oauth_token_secret"]!
                let uid = results["uid"]!
                return .success(DropboxAccessToken(accessToken: accessToken, uid: uid))
            } else {
                return .error(.unknown, "Unable to verify link request")
            }
        default:
            return .error(.accessDenied, "User cancelled Dropbox link")
        }
    }
    
    fileprivate func hasApplicationQueriesSchemes() -> Bool {
        let queriesSchemes = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        
        var foundApi2 = false
        var foundApi8Emm = false
        for scheme in queriesSchemes {
            if scheme == "dbapi-2" {
                foundApi2 = true
            } else if scheme == "dbapi-8-emm" {
                foundApi8Emm = true
            }
            if foundApi2 && foundApi8Emm {
                return true
            }
        }
        return false
    }
}

open class MobileSharedApplication: SharedApplication {
    public static var sharedMobileApplication: MobileSharedApplication?

    let sharedApplication: UIApplication
    let controller: UIViewController?
    let openURL: ((URL) -> Void)

    public init(sharedApplication: UIApplication, controller: UIViewController?, openURL: @escaping ((URL) -> Void)) {
        // fields saved for app-extension safety
        self.sharedApplication = sharedApplication
        self.controller = controller
        self.openURL = openURL
    }

    open func presentErrorMessage(_ message: String, title: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert)
        if let controller = controller {
            controller.present(alertController, animated: true, completion: { fatalError(message) })
        }
    }

    open func presentErrorMessageWithHandlers(_ message: String, title: String, buttonHandlers: Dictionary<String, () -> Void>) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert)

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            if let handler = buttonHandlers["Cancel"] {
                handler()
            }
        })

        alertController.addAction(UIAlertAction(title: "Retry", style: .default) { (_) in
            if let handler = buttonHandlers["Retry"] {
                handler()
            }
        })

        if let controller = controller {
            controller.present(alertController, animated: true, completion: {})
        }
    }

    open func presentPlatformSpecificAuth(_ authURL: URL) -> Bool {
        presentExternalApp(authURL)
        return true
    }

    open func presentAuthChannel(_ authURL: URL, tryIntercept: @escaping ((URL) -> Bool), cancelHandler: @escaping (() -> Void)) {
        if let controller = self.controller {
            let safariViewController = MobileSafariViewController(url: authURL, cancelHandler: cancelHandler)
            controller.present(safariViewController, animated: true, completion: nil)
        }
    }

    open func presentExternalApp(_ url: URL) {
        self.openURL(url)
    }

    open func canPresentExternalApp(_ url: URL) -> Bool {
        return self.sharedApplication.canOpenURL(url)
    }

    open func dismissAuthController() {
        if let controller = self.controller {
            if let presentedViewController = controller.presentedViewController {
                if presentedViewController.isBeingDismissed == false && presentedViewController is MobileSafariViewController {
                    controller.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
}

open class MobileSafariViewController: SFSafariViewController, SFSafariViewControllerDelegate {
    var cancelHandler: (() -> Void) = {}

    public init(url: URL, cancelHandler: @escaping (() -> Void)) {
			  super.init(url: url, entersReaderIfAvailable: false)
        self.cancelHandler = cancelHandler
        self.delegate = self;
    }

    public func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if (!didLoadSuccessfully) {
            controller.dismiss(animated: true, completion: nil)
        }
    }

    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.cancelHandler()
    }
    
}

