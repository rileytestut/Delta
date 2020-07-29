//
//  AppDelegate.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/28/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import GBADeltaCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate
{
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // Override point for customization after application launch.
        Delta.register(GBA.core)
        
        ExternalGameControllerManager.shared.startMonitoring()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        if let userActivity = options.userActivities.first, userActivity.activityType == "com.rileytestut.Delta.NewGame"
        {
//            connectingSceneSession.stateRestorationActivity = userActivity
            return UISceneConfiguration(name: "Game Configuration", sessionRole: connectingSceneSession.role)
        }

        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

