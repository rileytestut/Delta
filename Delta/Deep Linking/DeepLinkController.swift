//
//  DeepLinkController.swift
//  Delta
//
//  Created by Riley Testut on 12/28/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

#if os(iOS)
extension Notification.Name
{
    static let deepLinkControllerLaunchGame = Notification.Name("deepLinkControllerLaunchGame")
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
        guard let delegate = UIApplication.shared.delegate, let window = delegate.window else { return nil }
        return window
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
        case .launchGame(let identifier): return self.launchGame(withIdentifier: identifier)
        }
    }
}

private extension DeepLinkController
{
    func launchGame(withIdentifier identifier: String) -> Bool
    {
        guard let topViewController = self.topViewController, topViewController.allowsDeepLinkingDismissal else { return false }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), identifier)
        fetchRequest.returnsObjectsAsFaults = false
        
        do
        {
            guard let game = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first else { return false }
            
            NotificationCenter.default.post(name: .deepLinkControllerLaunchGame, object: self, userInfo: [DeepLink.Key.game: game])
        }
        catch
        {
            print(error)
            
            return false
        }
        
        return true
    }
}
#endif
