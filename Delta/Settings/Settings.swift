//
//  Settings.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import SNESDeltaCore
import GBADeltaCore

import Roxas

extension Notification.Name
{
    static let preferredControllerSkinDidUpdate = Notification.Name("PreferredControllerSkinDidUpdateNotification")
}

extension Settings
{
    enum NotificationUserInfoKey: String
    {
        case gameType
        case traits
    }
}

struct Settings
{
    /// Controllers
    static var localControllerPlayerIndex: Int? = 0
    
    static func preferredControllerSkin(for gameType: GameType, traits: DeltaCore.ControllerSkin.Traits) -> ControllerSkin?
    {
        guard let userDefaultsKey = self.preferredControllerSkinKey(for: gameType, traits: traits) else { return nil }
        
        let identifier = UserDefaults.standard.string(forKey: userDefaultsKey)
        
        do
        {
            // Attempt to load preferred controller skin if it exists
            
            let fetchRequest: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
            
            if let identifier = identifier
            {
                fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(ControllerSkin.gameType), gameType.rawValue, #keyPath(ControllerSkin.identifier), identifier)
                
                if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
                {
                    return controllerSkin
                }
            }
            
            // Controller skin doesn't exist, so fall back to standard controller skin
            
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == YES", #keyPath(ControllerSkin.gameType), gameType.rawValue, #keyPath(ControllerSkin.isStandard))
            
            if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
            {
                Settings.setPreferredControllerSkin(controllerSkin, for: gameType, traits: traits)
                return controllerSkin
            }
        }
        catch
        {
            print(error)
        }
        
        return nil
    }
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin, for gameType: GameType, traits: DeltaCore.ControllerSkin.Traits)
    {
        guard let userDefaultKey = self.preferredControllerSkinKey(for: gameType, traits: traits) else { return }
        UserDefaults.standard.set(controllerSkin.identifier, forKey: userDefaultKey)
        
        NotificationCenter.default.post(name: .preferredControllerSkinDidUpdate, object: controllerSkin, userInfo: [NotificationUserInfoKey.gameType.rawValue: gameType, NotificationUserInfoKey.traits.rawValue: traits])
    }
}

private extension Settings
{
    static func preferredControllerSkinKey(for gameType: GameType, traits: DeltaCore.ControllerSkin.Traits) -> String?
    {
        let systemName: String
        
        switch gameType
        {
        case GameType.snes: systemName = "snes"
        case GameType.gba: systemName = "gba"
        default: return nil
        }
        
        let orientation: String
        
        switch traits.orientation
        {
        case .portrait: orientation = "portrait"
        case .landscape: orientation = "landscape"
        }
        
        let displayMode: String
        
        switch traits.displayMode
        {
        case .fullScreen: displayMode = "fullscreen"
        case .splitView: displayMode = "splitview"
        }
        
        let key = systemName + "-" + orientation + "-" + displayMode + "-controller"
        return key
    }
}
