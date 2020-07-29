//
//  SceneDelegate.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/28/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

#if targetEnvironment(macCatalyst)

private extension NSToolbarItem.Identifier
{
    static let importGame: NSToolbarItem.Identifier = NSToolbarItem.Identifier(rawValue: "importGame")
}

#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

//        let rootViewController = UIHostingController(rootView: ContentView())
//        rootViewController.view.backgroundColor = .clear
        let rootViewController = RootViewController()

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        self.window = window
        
        #if targetEnvironment(macCatalyst)
        windowScene.titlebar?.titleVisibility = .hidden
        windowScene.titlebar?.separatorStyle = .none
        windowScene.titlebar?.toolbarStyle = .unified
        
        let identifier = NSToolbar.Identifier("com.example.apple-samplecode.toolbar")
        windowScene.titlebar?.toolbar = NSToolbar(identifier: identifier)
        windowScene.titlebar?.toolbar?.delegate = self
        #endif
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

#if targetEnvironment(macCatalyst)

extension SceneDelegate: NSToolbarDelegate
{
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        return [.importGame]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        return [.importGame]
    }
    
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
        var toolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButtonItem)
        
        /**Create a new NSToolbarItem, and then go through the process of setting up its
        attributes from the master toolbar item matching that identifier in the dictionary of items.
         */
//        if itemIdentifier == NSToolbarItem.Identifier.importGame {
//            // 1) Font style toolbar item.
//            toolbarItem =
//                customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.fontStyle.rawValue,
//                                  label: NSLocalizedString("Font Style", comment: ""),
//                                  paletteLabel: NSLocalizedString("Font Style", comment: ""),
//                                  toolTip: NSLocalizedString("tool tip font style", comment: ""),
//                                  itemContent: styleSegmentView)!
//        } else if itemIdentifier == NSToolbarItem.Identifier.fontSize {
//            // 2) Font size toolbar item.
//            toolbarItem =
//                customToolbarItem(itemForItemIdentifier: NSToolbarItem.Identifier.fontSize.rawValue,
//                                  label: NSLocalizedString("Font Size", comment: ""),
//                                  paletteLabel: NSLocalizedString("Font Size", comment: ""),
//                                  toolTip: NSLocalizedString("tool tip font size", comment: ""),
//                                  itemContent: fontSizeView)!
//        }
        
        return toolbarItem
    }
}

#endif
