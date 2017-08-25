//
//  AppDelegate.swift
//  Delta
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool
    {
        Fabric.with([Crashlytics.self])
        
        Settings.registerDefaults()
        
        System.supportedSystems.forEach { Delta.register($0.deltaCore) }
        
        self.configureAppearance()
        
        // Disable system gestures that delay touches on left edge of screen
        for gestureRecognizer in self.window?.gestureRecognizers ?? [] where NSStringFromClass(type(of: gestureRecognizer)).contains("GateGesture")
        {
            gestureRecognizer.delaysTouchesBegan = false
        }
        
        // Database
        
        DatabaseManager.shared.loadPersistentStores { (description, error) in
        }
        
        // Controllers
        ExternalControllerManager.shared.startMonitoringExternalControllers()
                
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

extension AppDelegate
{
    func configureAppearance()
    {
        self.window?.tintColor = UIColor.deltaPurple
        
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes[NSForegroundColorAttributeName] = UIColor.white
    }
}

extension AppDelegate
{
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool
    {
        return self.openURL(url)
    }
    
    @discardableResult fileprivate func openURL(_ url: URL) -> Bool
    {
        guard url.isFileURL else { return false }
        
        if GameType(fileExtension: url.pathExtension) != nil || url.pathExtension.lowercased() == "zip"
        {
            return self.importGame(at: url)
        }
        else if url.pathExtension.lowercased() == "deltaskin"
        {
            return self.importControllerSkin(at: url)
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

