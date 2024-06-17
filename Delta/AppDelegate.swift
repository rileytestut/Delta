//
//  AppDelegate.swift
//  Delta
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import Harmony
import AltKit

private extension CFNotificationName
{
    static let altstoreRequestAppState: CFNotificationName = CFNotificationName("com.altstore.RequestAppState.com.rileytestut.Delta" as CFString)
    static let altstoreAppIsRunning: CFNotificationName = CFNotificationName("com.altstore.AppState.Running.com.rileytestut.Delta" as CFString)
}

private let ReceivedApplicationState: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    appDelegate.receivedApplicationStateRequest()
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    private let deepLinkController = DeepLinkController(window: nil)
    private var appLaunchDeepLink: DeepLink?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        Settings.registerDefaults()
        
        self.registerCores()
        self.configureAppearance()
        
        // Controllers
        ExternalGameControllerManager.shared.startMonitoring()
        
        // JIT
        ServerManager.shared.prepare()
        
        // Notifications
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, ReceivedApplicationState, CFNotificationName.altstoreRequestAppState.rawValue, nil, .deliverImmediately)
        
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.databaseManagerDidStart(_:)), name: DatabaseManager.didStartNotification, object: DatabaseManager.shared)
        

        // Deep Links
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        {
            self.appLaunchDeepLink = .shortcut(shortcut)
            
            // false = we handled the deep link, so no need to call delegate method separately.
            return false
        }
                
        return true
    }

    func applicationWillResignActive(_ application: UIApplication)
    {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication)
    {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication)
    {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication)
    {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication)
    {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

@available(iOS 13, *)
extension AppDelegate
{
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        
        if connectingSceneSession.role == .windowExternalDisplay
        {
            // External Display
            return UISceneConfiguration(name: "External Display", sessionRole: connectingSceneSession.role)
        }
        else if options.userActivities.contains(where: { $0.activityType == NSUserActivity.playGameActivityType })
        {
            // Game Scene
            return UISceneConfiguration(name: "Game", sessionRole: connectingSceneSession.role)
        }
        else
        {
            // Default Scene
            return UISceneConfiguration(name: "Main", sessionRole: connectingSceneSession.role)
        }
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>)
    {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

private extension AppDelegate
{
    func registerCores()
    {
        #if LITE
        
        #if BETA
        Delta.register(System.nes.deltaCore)
        Delta.register(System.gbc.deltaCore)
        #else
        Delta.register(System.nes.deltaCore)
        #endif
        
        #else
        
        #if BETA
        System.allCases.forEach { Delta.register($0.deltaCore) }
        #else
        System.allCases.filter { $0 != .genesis }.forEach { Delta.register($0.deltaCore) }
        #endif
        
        #endif
    }
    
    func configureAppearance()
    {
        self.window?.tintColor = UIColor.deltaPurple
    }
}

extension AppDelegate
{
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
    {
        return self.openURL(url)
    }
    
    @discardableResult private func openURL(_ url: URL) -> Bool
    {
        if url.isFileURL
        {
            if GameType(fileExtension: url.pathExtension) != nil || url.pathExtension.lowercased() == "zip"
            {
                return self.importGame(at: url)
            }
            else if url.pathExtension.lowercased() == "deltaskin"
            {
                return self.importControllerSkin(at: url)
            }
        }
        else if url.scheme?.hasPrefix("db-") == true
        {
            return DropboxService.shared.handleDropboxURL(url)
        }
        else if url.scheme?.lowercased() == "delta"
        {
            return self.deepLinkController.handle(.url(url))
        }
        
        return false
    }
    
    private func importGame(at url: URL) -> Bool
    {
        DatabaseManager.shared.importGames(at: [url]) { (games, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .games, with: errors)
                self.present(alertController)
            }
        }
        
        return true
    }
    
    private func importControllerSkin(at url: URL) -> Bool
    {
        DatabaseManager.shared.importControllerSkins(at: [url]) { (games, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .controllerSkins, with: errors)
                self.present(alertController)
            }
        }
        
        return true
    }
    
    private func present(_ alertController: UIAlertController)
    {
        var rootViewController = self.window?.rootViewController
        
        while rootViewController?.presentedViewController != nil
        {
            rootViewController = rootViewController?.presentedViewController
        }
        
        rootViewController?.present(alertController, animated: true, completion: nil)
    }
}

extension AppDelegate
{
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void)
    {
        let result = self.deepLinkController.handle(.shortcut(shortcutItem))
        completionHandler(result)
    }
}

private extension AppDelegate
{
    @objc func databaseManagerDidStart(_ notification: Notification)
    {
        guard let deepLink = self.appLaunchDeepLink else { return }
        
        DispatchQueue.main.async {
            self.deepLinkController.handle(deepLink)
        }
    }
    
    func receivedApplicationStateRequest()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center!, CFNotificationName(CFNotificationName.altstoreAppIsRunning.rawValue), nil, nil, true)
    }
}

