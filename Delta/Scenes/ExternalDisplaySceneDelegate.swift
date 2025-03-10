//
//  ExternalDisplaySceneDelegate.swift
//  Delta
//
//  Created by Riley Testut on 4/17/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension UIApplication
{
    var isExternalDisplayConnected: Bool {
        guard Settings.supportsExternalDisplays else { return false }
        
        let scene = UIApplication.shared.connectedScenes.first { $0.session.role == .windowExternalDisplay }
        return scene != nil
    }
    
    var externalDisplayScene: ExternalDisplayScene? {
        guard Settings.supportsExternalDisplays else { return nil }
        
        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? ExternalDisplayScene }).first(where: { $0.session.role == .windowExternalDisplay })
        return scene
    }
}

class ExternalDisplayScene: UIWindowScene
{
    let gameViewController = DeltaCore.GameViewController()
    
    var game: GameProtocol? {
        get { self.gameViewController.game }
        set { self.gameViewController.game = newValue }
    }
}

class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?
    
    private weak var scene: ExternalDisplayScene?
        
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let externalDisplayScene = scene as? ExternalDisplayScene else { return }
        self.scene = externalDisplayScene
        
        // If we don't attach a window, iOS won't show the scene.
        if Settings.supportsExternalDisplays
        {
            self.prepare(externalDisplayScene)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalDisplaySceneDelegate.settingsDidChange(with:)), name: .settingsDidChange, object: nil)
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
    }
    
    func sceneDidEnterBackground(_ scene: UIScene)
    {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

private extension ExternalDisplaySceneDelegate
{
    func prepare(_ scene: ExternalDisplayScene)
    {
        guard self.window == nil else { return }
        
        self.window = GameWindow(windowScene: scene)
        self.window?.tintColor = .deltaPurple
        self.window?.rootViewController = scene.gameViewController
        self.window?.makeKeyAndVisible()
    }
    
    @objc func settingsDidChange(with notification: Notification)
    {
        guard let settingsName = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name, settingsName == .supportsExternalDisplays else { return }
        guard let scene else { return }
        
        if Settings.supportsExternalDisplays
        {
            self.prepare(scene)
        }
        else
        {
            // Hide ourselves
            self.window?.isHidden = true
            self.window?.removeFromSuperview()
            self.window = nil
        }
    }
}
