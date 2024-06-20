//
//  GameSceneDelegate.swift
//  Delta
//
//  Created by Riley Testut on 5/7/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

extension UIApplication
{
    var gameSessions: Set<UISceneSession> {
        let sessions = self.openSessions.lazy.filter { !UISceneSession._discardedSessions.contains($0) }.filter { $0.userInfo?[NSUserActivity.gameIDKey] != nil }
        return Set(sessions)
    }
}

class GameScene: UIWindowScene
{
    fileprivate(set) var game: Game? {
        didSet {
            self.title = self.game?.name
        }
    }
}

class GameSceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?
        
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let gameScene = scene as? GameScene else { return }
        
        self.window?.tintColor = .deltaPurple
        
        DatabaseManager.shared.start { error in
            guard error == nil else {
                Logger.main.error("Failed to load database for GameScene. \(error!.localizedDescription, privacy: .public)")
                return
            }
            
            DispatchQueue.main.async {
                let gameID: String
                
                if let userActivity = session.stateRestorationActivity ?? connectionOptions.userActivities.first, userActivity.activityType == NSUserActivity.playGameActivityType,
                   let activityGameID = userActivity.userInfo?[NSUserActivity.gameIDKey] as? String
                {
                    gameID = activityGameID
                }
                else if let previousGameID = session.userInfo?[NSUserActivity.gameIDKey] as? String
                {
                    gameID = previousGameID
                }
                else
                {
                    return
                }
                
                // Persist gameID for state restoration.
                session.userInfo?[NSUserActivity.gameIDKey] = gameID
                
                let predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), gameID)
                if let game = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self).first
                {
                    let launchViewController = self.window?.rootViewController as? LaunchViewController
                    launchViewController?.deepLinkGame = game
                    
                    gameScene.game = game
                    session.userInfo?[NSUserActivity.systemIDKey] = game.type.rawValue
                }
                else
                {
                    Logger.main.error("Could not find game with ID \(gameID, privacy: .public).")
                }
            }
        }
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity?
    {
        // Support state restoration for dedicated GameScenes.
        return scene.userActivity
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
