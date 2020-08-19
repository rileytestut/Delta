//
//  GameSceneDelegate.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/28/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

import GBADeltaCore

class GameWindow: UIWindow
{
    var videoDimensions: CGSize? {
        didSet {
            NSLayoutConstraint.deactivate(self.aspectRatioConstraints)
            self.aspectRatioConstraints = []
            
            if let videoDimensions = self.videoDimensions
            {
                self.aspectRatioConstraints = [self.safeAreaLayoutGuide.widthAnchor.constraint(equalTo: self.safeAreaLayoutGuide.heightAnchor,
                                                                                               multiplier: videoDimensions.width / videoDimensions.height),
                                               self.safeAreaLayoutGuide.widthAnchor.constraint(equalToConstant: videoDimensions.width * 2),
                                               self.safeAreaLayoutGuide.heightAnchor.constraint(equalToConstant: videoDimensions.height * 2)]
                NSLayoutConstraint.activate(self.aspectRatioConstraints)
            }
        }
    }
    
    private var aspectRatioConstraints: [NSLayoutConstraint] = []
}

class GameSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private var cancellables = Set<AnyCancellable>()
    
    override init()
    {
        super.init()
        
        self.prepareSubscriptions()
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        guard let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity else { return }
        
//        session.stateRestorationActivity = userActivity
        
        guard let identifier = userActivity.userInfo?["identifier"] as? String else { return }

        let game = Game.instancesWithPredicate(NSPredicate(format: "%K == %@", #keyPath(Game.identifier), identifier), inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self).first!
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

//        let rootViewController = UIHostingController(rootView: ContentView())
//        rootViewController.view.backgroundColor = .clear
        var rootViewController = GameView(game: game)
        
        if let rawLinkRole = userActivity.userInfo?["linkRole"] as? Int, let linkRole = LinkRole(rawValue: rawLinkRole)
        {
            rootViewController.linkRole = linkRole
        }

        let window = GameWindow(windowScene: windowScene)
        window.canResizeToFitContent = true
        window.rootViewController = UIHostingController(rootView: rootViewController)
        window.makeKeyAndVisible()
        self.window = window
        
        session.userInfo = ["gameType": game.type]
        
        #if targetEnvironment(macCatalyst)
        windowScene.title = game.name
        windowScene.titlebar?.titleVisibility = .visible
        windowScene.titlebar?.separatorStyle = .none
        windowScene.titlebar?.toolbarStyle = .unifiedCompact
                
        let identifier2 = NSToolbar.Identifier("com.example.apple-samplecode.toolbar")
        let toolbar = NSToolbar(identifier: identifier2)
        windowScene.titlebar?.toolbar = toolbar
        windowScene.titlebar?.autoHidesToolbarInFullScreen = true
        
        if let core = Delta.core(for: game.type)
        {
            windowScene.sizeRestrictions?.minimumSize = core.videoFormat.dimensions
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
            
            window.videoDimensions = core.videoFormat.dimensions
            
            // Set preferred initial frame.
//            window.frame = CGRect(origin: .zero, size: core.videoFormat.dimensions.applying(.init(scaleX: 2, y: 2)))
        }
        #endif
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity)
    {
        print("Activity:", userActivity)
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

private extension GameSceneDelegate
{
    func prepareSubscriptions()
    {
        #if targetEnvironment(macCatalyst)
        NotificationCenter.default.publisher(for: .DLTAWindowDidBecomeKey)
            .receive(on: RunLoop.main)
            .sink { _ in self.updateWindows() }
            .store(in: &self.cancellables)
        #endif
    }
    
    #if targetEnvironment(macCatalyst)
    func updateWindows()
    {
        guard let window = self.window as? GameWindow,
              let windowScene = window.windowScene,
              let gameType = windowScene.session.userInfo?["gameType"] as? GameType,
              let core = Delta.core(for: gameType) else { return }
        
        guard window.canResizeToFitContent else { return }
        window.canResizeToFitContent = false
        window.videoDimensions = nil
        
        if let nsWindow = window.nsWindow
        {
            var frame = nsWindow.frame
            frame.size = window.frame.size
            
            nsWindow.styleMask.remove(.proxyStyleMaskFullSizeContentView)
            nsWindow.contentAspectRatio = core.videoFormat.dimensions
            nsWindow.setFrame(frame, display: true)
        }
//        window.setNeedsLayout()
//        window.nsWindow?.setContentSize(core.videoFormat.dimensions.applying(.init(scaleX: 2, y: 2)))
    }
    #endif
}
