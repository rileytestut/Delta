//
//  AppDelegate.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/27/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore
import GBADeltaCore

class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        ExternalGameControllerManager.shared.startMonitoring()
        
        print(FileManager.default.documentsDirectory)
        Delta.register(GBA.core)
//        System.allCases.forEach { Delta.register($0.deltaCore) }
        
        return true
    }    
}
