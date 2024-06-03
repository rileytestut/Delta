//
//  DeepLink.swift
//  Delta
//
//  Created by Riley Testut on 12/29/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

extension URL
{
    init(action: DeepLink.Action)
    {
        switch action
        {
        case .launchGame(let identifier, _):
            let deepLinkURL = URL(string: "delta://\(action.type.rawValue)/\(identifier)")!
            self = deepLinkURL
        }
    }
}

extension UIApplicationShortcutItem
{
    convenience init(localizedTitle: String, action: DeepLink.Action)
    {
        var userInfo: [String: NSSecureCoding]?
        
        switch action
        {
        case .launchGame(let identifier, _): userInfo = [DeepLink.Key.identifier.rawValue: identifier as NSString]
        }
        
        self.init(type: action.type.rawValue, localizedTitle: localizedTitle, localizedSubtitle: nil, icon: nil, userInfo: userInfo)
    }
}

extension DeepLink
{
    enum Action
    {
        case launchGame(identifier: String, userActivity: NSUserActivity?)
        
        var type: ActionType {
            switch self
            {
            case .launchGame: return .launchGame
            }
        }
    }
    
    enum ActionType: String
    {
        case launchGame = "game"
    }
    
    enum Key: String
    {
        case identifier
        case game
        case saveState
    }
}

enum DeepLink
{
    case url(URL)
    case shortcut(UIApplicationShortcutItem)
    case handoff(NSUserActivity)
    
    var actionType: ActionType? {
        switch self
        {
        case .url(let url):
            guard let host = url.host else { return nil }
            
            let type = ActionType(rawValue: host)
            return type
            
        case .shortcut(let shortcut):
            let type = ActionType(rawValue: shortcut.type)
            return type
            
        case .handoff(let userActivity):
            return .launchGame
        }
    }
    
    var action: Action? {
        guard let type = self.actionType else { return nil }
        
        switch (self, type)
        {
        case (.url(let url), .launchGame):
            let identifier = url.lastPathComponent
            return .launchGame(identifier: identifier, userActivity: nil)
            
        case (.shortcut(let shortcut), .launchGame):
            guard let identifier = shortcut.userInfo?[Key.identifier.rawValue] as? String else { return nil }
            return .launchGame(identifier: identifier, userActivity: nil)
            
        case (.handoff(let userActivity), .launchGame):
            guard let identifier = userActivity.userInfo?[NSUserActivity.gameIDKey] as? String else { return nil }
            return .launchGame(identifier: identifier, userActivity: userActivity)
        }
    }
}
