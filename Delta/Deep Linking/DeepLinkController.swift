//
//  DeepLinkController.swift
//  Delta
//
//  Created by Riley Testut on 12/28/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension Notification.Name
{
    static let deepLinkControllerLaunchGame = Notification.Name("deepLinkControllerLaunchGame")
    static let deepLinkControllerLoadSaveState = Notification.Name("deepLinkControllerLoadSaveState")
}

extension UIViewController
{
    var allowsDeepLinkingDismissal: Bool {
        return true
    }
}

struct DeepLinkController
{
    private var window: UIWindow? {
        if #available(iOS 13, *)
        {
            guard let delegate = UIApplication.shared.connectedScenes.lazy.compactMap({ $0.delegate as? UIWindowSceneDelegate }).first, let window = delegate.window else { return nil }
            return window
        }
        else
        {
            guard let delegate = UIApplication.shared.delegate, let window = delegate.window else { return nil }
            return window
        }
    }
    
    private var topViewController: UIViewController? {
        guard let window = self.window else { return nil }
        
        var topViewController = window.rootViewController
        while topViewController?.presentedViewController != nil
        {
            guard !(topViewController?.presentedViewController is UIAlertController) else { break }
            
            topViewController = topViewController?.presentedViewController
        }
        
        return topViewController
    }
}

extension DeepLinkController
{
    @discardableResult func handle(_ deepLink: DeepLink) -> Bool
    {
        guard let action = deepLink.action else { return false }
        
        switch action
        {
        case .launchGame(let identifier, let userActivity): return self.launchGame(withIdentifier: identifier, userActivity: userActivity)
        }
    }
}

private extension DeepLinkController
{
    func launchGame(withIdentifier identifier: String, userActivity: NSUserActivity?) -> Bool
    {
        guard let topViewController = self.topViewController, topViewController.allowsDeepLinkingDismissal else { return false }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), identifier)
        fetchRequest.returnsObjectsAsFaults = false
        
        do
        {
            guard let game = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first else { return false }
            
            var userInfo: [DeepLink.Key: Any] = [.game: game]
            
            if let userActivity, userActivity.activityType == NSUserActivity.playGameActivityType//,
               //let hasSaveState = userActivity.userInfo?[NSUserActivity.hasSaveStateKey] as? Bool, hasSaveState
            {
                let temporaryURL = FileManager.default.uniqueTemporaryURL()
                
                let placeholderSaveState = DeltaCore.SaveState(fileURL: temporaryURL, gameType: game.type)
                userInfo[.saveState] = placeholderSaveState
                
                Task<Void, Never> { [userInfo] in
                    do
                    {
                        let (inputStream, outputStream) = try await userActivity.continuationStreams()
                        inputStream.open()
                        outputStream.open()
                        
                        let data: Data = try await inputStream.receive()
                        
                        
                        Logger.main.error("Read \(data.count) bytes from Handoff!")
                        
                        try data.write(to: temporaryURL, options: .atomic)
                        
                        NotificationCenter.default.post(name: .deepLinkControllerLoadSaveState, object: self, userInfo: userInfo)
                        
                    }
                    catch
                    {
                        Logger.main.error("Failed to retrieve streams for Handoff. \(error.localizedDescription, privacy: .public)")
//                        NotificationCenter.default.post(name: .deepLinkControllerLoadSaveState, object: self, userInfo: userInfo)
                    }
                }
            }
            
            NotificationCenter.default.post(name: .deepLinkControllerLaunchGame, object: self, userInfo: userInfo)
        }
        catch
        {
            print(error)
            
            return false
        }
        
        return true
    }
}
