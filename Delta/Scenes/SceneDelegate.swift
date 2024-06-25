//
//  SceneDelegate.swift
//  Delta
//
//  Created by Riley Testut on 6/6/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import Harmony

extension UIApplication
{
    var mainScenes: Set<UIScene> {
        let scenes = self.connectedScenes.lazy.filter { !UISceneSession._discardedSessions.contains($0.session) }.filter { $0.delegate is SceneDelegate }
        return Set(scenes)
    }
}

@objc(SceneDelegate) @available(iOS 13, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow? {
        get {
            if _window == nil
            {
                _window = GameWindow()
            }
            
            return _window
        }
        set {
            _window = newValue as? GameWindow
        }
    }
    private var _window: GameWindow?
    
    var game: Game? {
        return self.launchViewController.gameViewController.game as? Game
    }
    
    private lazy var deepLinkController = DeepLinkController(window: self.window)
    private var launchViewController: LaunchViewController!
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        // Become default scene handler for Handoff/other deep links.
        scene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
        
        self.window?.tintColor = .deltaPurple
        
        if let context = connectionOptions.urlContexts.first
        {
            self.handle(.url(context.url))
        }
        
        if let shortcutItem = connectionOptions.shortcutItem
        {
            self.handle(.shortcut(shortcutItem))
        }
        
        let launchViewController = self.window?.rootViewController as! LaunchViewController
        self.launchViewController = launchViewController
        
        self.window?.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene)
    {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene)
    {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene)
    {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene)
    {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        guard DatabaseManager.shared.isStarted else { return }
        PatreonAPI.shared.refreshPatreonAccount()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene)
    {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

@available(iOS 13, *)
extension SceneDelegate
{
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
    {
        guard let context = URLContexts.first else { return }
        self.handle(.url(context.url))
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void)
    {
        self.handle(.shortcut(shortcutItem))
        completionHandler(true)
    }
    
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String)
    {
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity)
    {
        guard userActivity.activityType == NSUserActivity.playGameActivityType else { return }
        self.handle(.handoff(userActivity))
    }
    
    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: any Error)
    {
        guard userActivityType == NSUserActivity.playGameActivityType else { return }
        
        Logger.main.error("Failed to continue game via Handoff. \(error.localizedDescription, privacy: .public)")
        
        let alertController = UIAlertController(title: NSLocalizedString("Handoff Failed", comment: ""), error: error)
        self.present(alertController)
    }
}

@available(iOS 13, *)
private extension SceneDelegate
{
    func handle(_ deepLink: DeepLink)
    {
        guard DatabaseManager.shared.isStarted else {
            // Wait until DatabaseManager is ready before handling deep link.
            
            // NotificationCenter.default.notifications requires iOS 15 or later :(
            // _ = await NotificationCenter.default.notifications(named: DatabaseManager.didStartNotification).first(where: { _ in true })
            
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(forName: DatabaseManager.didStartNotification, object: DatabaseManager.shared, queue: .main) { [weak observer] _ in
                observer.map { NotificationCenter.default.removeObserver($0) }
                self.handle(deepLink)
            }
            
            return
        }
        
        DispatchQueue.main.async {
            // DeepLinkController expects to be called from main thread.
            
            switch deepLink
            {
            case .shortcut: _ = self.deepLinkController.handle(deepLink)
            case .handoff(let userActivity) where userActivity.activityType == NSUserActivity.playGameActivityType:
                do
                {
                    guard let gameID = userActivity.userInfo?[NSUserActivity.gameIDKey] as? String else {
                        throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedFailureReasonErrorKey: NSLocalizedString("The game's identifier is missing.", comment: "")])
                    }
                    
                    let fetchRequest = Game.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), gameID)
                    
                    let count = try DatabaseManager.shared.viewContext.count(for: fetchRequest)
                    guard count > 0 else { throw DeepLink.Error.gameNotFound(gameID) }
                    
                    _ = self.deepLinkController.handle(deepLink)
                }
                catch
                {
                    Logger.main.error("Failed to load game for Handoff. \(error.localizedDescription, privacy: .public)")
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Handoff Failed", comment: ""), error: error)
                    self.present(alertController)
                }
                
            case .handoff: _ = self.deepLinkController.handle(deepLink)
            case .url(let url):
                if url.isFileURL
                {
                    if GameType(fileExtension: url.pathExtension) != nil || url.pathExtension.lowercased() == "zip"
                    {
                        self.importGame(at: url)
                    }
                    else if url.pathExtension.lowercased() == "deltaskin"
                    {
                        self.importControllerSkin(at: url)
                    }
                }
                else if url.scheme?.hasPrefix("db-") == true
                {
                    _ = DropboxService.shared.handleDropboxURL(url)
                }
                else if url.scheme?.lowercased() == "delta"
                {
                    _ = self.deepLinkController.handle(deepLink)
                }
            }
        }
    }
    
    func importGame(at url: URL)
    {
        DatabaseManager.shared.importGames(at: [url]) { (games, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .games, with: errors)
                self.present(alertController)
            }
        }
    }
    
    func importControllerSkin(at url: URL)
    {
        DatabaseManager.shared.importControllerSkins(at: [url]) { (games, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .controllerSkins, with: errors)
                self.present(alertController)
            }
        }
    }
    
    func present(_ alertController: UIAlertController)
    {
        var rootViewController = self.window?.rootViewController
        
        while rootViewController?.presentedViewController != nil
        {
            rootViewController = rootViewController?.presentedViewController
        }
        
        rootViewController?.present(alertController, animated: true, completion: nil)
    }
}
