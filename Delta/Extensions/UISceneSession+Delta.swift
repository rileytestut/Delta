//
//  UISceneSession+Delta.swift
//  Delta
//
//  Created by Riley Testut on 6/20/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import UIKit

extension UISceneSession
{
    // Intentionally named quit in case Apple adds official notification for discarded sessions later.
    static let willQuitNotification = Notification.Name("DLTASceneSessionWillQuitNotification")
}

extension UISceneSession
{
    // Hack to work around iPadOS bug (as of 17.4.1) where discarding backgrounded scenes doesn't update UIApplication.openSessions.
    static var _discardedSessions = Set<UISceneSession>()
    
    func quit()
    {
        NotificationCenter.default.post(name: UISceneSession.willQuitNotification, object: self)
        
        UIApplication.shared.requestSceneSessionDestruction(self, options: nil) { error in
            Logger.main.error("Failed to quit scene session. \(error.localizedDescription, privacy: .public)")
            
            let nsError = error as NSError
            if nsError.domain == "SBApplicationSupportService" && nsError.code == 2 && self.scene == nil
            {
                // "No scene handles found for provided persistence IDs"
                // Can be a false positive, so assume success if scene == nil.
            }
            else
            {
                UISceneSession._discardedSessions.remove(self)
            }
        }
        
        UISceneSession._discardedSessions.insert(self)
    }
}
