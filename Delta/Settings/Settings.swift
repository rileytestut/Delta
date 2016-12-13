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
    static let settingsDidChange = Notification.Name("SettingsDidChangeNotification")
}

extension Settings
{
    enum NotificationUserInfoKey: String
    {
        case name
        
        case gameType
        case traits
    }
    
    enum Name: String
    {
        case localControllerPlayerIndex
        case translucentControllerSkinOpacity
        case preferredControllerSkin
    }
}

struct Settings
{
    /// Controllers
    static var localControllerPlayerIndex: Int? = 0 {
        didSet {
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.localControllerPlayerIndex])
        }
    }
    
    static var translucentControllerSkinOpacity: CGFloat {
        set {
            UserDefaults.standard.translucentControllerSkinOpacity = newValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.translucentControllerSkinOpacity])
        }
        get { return UserDefaults.standard.translucentControllerSkinOpacity }
    }
    
    static var previousGameCollection: GameCollection? {
        set { UserDefaults.standard.previousGameCollectionIdentifier = newValue?.identifier }
        get {
            guard let identifier = UserDefaults.standard.previousGameCollectionIdentifier else { return nil }
            
            let predicate = NSPredicate(format: "%K == %@", #keyPath(GameCollection.identifier), identifier)
            
            let gameCollection = GameCollection.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: GameCollection.self)
            return gameCollection.first
        }
    }
    
    static func registerDefaults()
    {
        let defaults = [#keyPath(UserDefaults.translucentControllerSkinOpacity): 0.7]
        UserDefaults.standard.register(defaults: defaults)
    }
    
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
        
        NotificationCenter.default.post(name: .settingsDidChange, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.gameType: gameType, NotificationUserInfoKey.traits: traits])
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

private extension UserDefaults
{
    @NSManaged var translucentControllerSkinOpacity: CGFloat
    @NSManaged var previousGameCollectionIdentifier: String?
}
