//
//  Settings.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

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
        
        case system
        case traits
    }
    
    enum Name: String
    {
        case localControllerPlayerIndex
        case translucentControllerSkinOpacity
        case preferredControllerSkin
    }
}

extension Settings
{
    enum GameShortcutsMode: String
    {
        case recent
        case manual
    }
}

struct Settings
{
    /// Controllers
    static var localControllerPlayerIndex: Int? = 0 {
        didSet {
            guard self.localControllerPlayerIndex != oldValue else { return }
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.localControllerPlayerIndex])
        }
    }
    
    static var translucentControllerSkinOpacity: CGFloat {
        set {
            guard newValue != self.translucentControllerSkinOpacity else { return }
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
    
    static var gameShortcutsMode: GameShortcutsMode {
        set { UserDefaults.standard.gameShortcutsMode = newValue.rawValue }
        get {
            let mode = GameShortcutsMode(rawValue: UserDefaults.standard.gameShortcutsMode) ?? .recent
            return mode
        }
    }
    
    static var gameShortcuts: [Game] {
        set {
            let identifiers = newValue.map { $0.identifier }
            UserDefaults.standard.gameShortcutIdentifiers = identifiers
            
            let shortcuts = newValue.map { UIApplicationShortcutItem(localizedTitle: $0.name, action: .launchGame(identifier: $0.identifier)) }
            
            DispatchQueue.main.async {
                UIApplication.shared.shortcutItems = shortcuts
            }
        }
        get {
            let identifiers = UserDefaults.standard.gameShortcutIdentifiers
            
            do
            {
                let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(Game.identifier), identifiers)
                fetchRequest.returnsObjectsAsFaults = false
                
                let games = try DatabaseManager.shared.viewContext.fetch(fetchRequest).sorted(by: { (game1, game2) -> Bool in
                    let index1 = identifiers.index(of: game1.identifier)!
                    let index2 = identifiers.index(of: game2.identifier)!
                    return index1 < index2
                })
                
                return games
            }
            catch
            {
                print(error)
            }
            
            return []
        }
    }
    
    static func registerDefaults()
    {
        let defaults = [#keyPath(UserDefaults.translucentControllerSkinOpacity): 0.7, #keyPath(UserDefaults.gameShortcutsMode): GameShortcutsMode.recent.rawValue] as [String : Any]
        UserDefaults.standard.register(defaults: defaults)
    }
    
    static func preferredControllerSkin(for system: System, traits: DeltaCore.ControllerSkin.Traits) -> ControllerSkin?
    {
        guard let userDefaultsKey = self.preferredControllerSkinKey(for: system, traits: traits) else { return nil }
        
        let identifier = UserDefaults.standard.string(forKey: userDefaultsKey)
        
        do
        {
            // Attempt to load preferred controller skin if it exists
            
            let fetchRequest: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
            
            if let identifier = identifier
            {
                fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.identifier), identifier)
                
                if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
                {
                    return controllerSkin
                }
            }
            
            // Controller skin doesn't exist, so fall back to standard controller skin
            
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == YES", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.isStandard))
            
            if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
            {
                Settings.setPreferredControllerSkin(controllerSkin, for: system, traits: traits)
                return controllerSkin
            }
        }
        catch
        {
            print(error)
        }
        
        return nil
    }
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin, for system: System, traits: DeltaCore.ControllerSkin.Traits)
    {
        guard let userDefaultKey = self.preferredControllerSkinKey(for: system, traits: traits) else { return }
        
        guard UserDefaults.standard.string(forKey: userDefaultKey) != controllerSkin.identifier else { return }
        
        UserDefaults.standard.set(controllerSkin.identifier, forKey: userDefaultKey)
        
        NotificationCenter.default.post(name: .settingsDidChange, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.system: system, NotificationUserInfoKey.traits: traits])
    }
}

private extension Settings
{
    static func preferredControllerSkinKey(for system: System, traits: DeltaCore.ControllerSkin.Traits) -> String?
    {
        let systemName: String
        
        switch system
        {
        case .nes: systemName = "nes"
        case .snes: systemName = "snes"
        case .gbc: systemName = "gbc"
        case .gba: systemName = "gba"
        }
        
        let orientation: String
        
        switch traits.orientation
        {
        case .portrait: orientation = "portrait"
        case .landscape: orientation = "landscape"
        }
        
        let displayType: String
        
        switch traits.displayType
        {
        case .standard: displayType = "standard"
        case .edgeToEdge: displayType = "standard" // In this context, standard and edge-to-edge skins are treated the same.
        case .splitView: displayType = "splitview"
        }
        
        let key = systemName + "-" + orientation + "-" + displayType + "-controller"
        return key
    }
}

private extension UserDefaults
{
    @NSManaged var translucentControllerSkinOpacity: CGFloat
    @NSManaged var previousGameCollectionIdentifier: String?
    
    @NSManaged var gameShortcutsMode: String
    @NSManaged var gameShortcutIdentifiers: [String]
}
