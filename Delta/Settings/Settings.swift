//
//  Settings.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import MelonDSDeltaCore

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
        
        case core
    }
    
    enum Name: String
    {
        case localControllerPlayerIndex
        case translucentControllerSkinOpacity
        case preferredControllerSkin
        case syncingService
        case isButtonHapticFeedbackEnabled
        case isThumbstickHapticFeedbackEnabled
        case isAltJITEnabled
        case respectSilentMode
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
    static func registerDefaults()
    {
        let defaults = [#keyPath(UserDefaults.translucentControllerSkinOpacity): 0.7,
                        #keyPath(UserDefaults.gameShortcutsMode): GameShortcutsMode.recent.rawValue,
                        #keyPath(UserDefaults.isButtonHapticFeedbackEnabled): true,
                        #keyPath(UserDefaults.isThumbstickHapticFeedbackEnabled): true,
                        #keyPath(UserDefaults.sortSaveStatesByOldestFirst): true,
                        #keyPath(UserDefaults.isPreviewsEnabled): true,
                        #keyPath(UserDefaults.isAltJITEnabled): false,
                        #keyPath(UserDefaults.respectSilentMode): true,
                        Settings.preferredCoreSettingsKey(for: .ds): MelonDS.core.identifier] as [String : Any]
        UserDefaults.standard.register(defaults: defaults)
        
        #if !BETA
        // Manually set MelonDS as preferred DS core in case DeSmuME is cached from a previous version.
        UserDefaults.standard.set(MelonDS.core.identifier, forKey: Settings.preferredCoreSettingsKey(for: .ds))
        #endif
    }
}

extension Settings
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
                    let index1 = identifiers.firstIndex(of: game1.identifier)!
                    let index2 = identifiers.firstIndex(of: game2.identifier)!
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
    
    static var syncingService: SyncManager.Service? {
        get {
            guard let syncingService = UserDefaults.standard.syncingService else { return nil }
            return SyncManager.Service(rawValue: syncingService)
        }
        set {
            UserDefaults.standard.syncingService = newValue?.rawValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.syncingService])
        }
    }
    
    static var isButtonHapticFeedbackEnabled: Bool {
        get {
            let isEnabled = UserDefaults.standard.isButtonHapticFeedbackEnabled
            return isEnabled
        }
        set {
            UserDefaults.standard.isButtonHapticFeedbackEnabled = newValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isButtonHapticFeedbackEnabled])
        }
    }
    
    static var isThumbstickHapticFeedbackEnabled: Bool {
        get {
            let isEnabled = UserDefaults.standard.isThumbstickHapticFeedbackEnabled
            return isEnabled
        }
        set {
            UserDefaults.standard.isThumbstickHapticFeedbackEnabled = newValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isThumbstickHapticFeedbackEnabled])
        }
    }
    
    static var sortSaveStatesByOldestFirst: Bool {
        set { UserDefaults.standard.sortSaveStatesByOldestFirst = newValue }
        get {
            let sortByOldestFirst = UserDefaults.standard.sortSaveStatesByOldestFirst
            return sortByOldestFirst
        }
    }
    
    static var isPreviewsEnabled: Bool {
        set { UserDefaults.standard.isPreviewsEnabled = newValue }
        get {
            let isPreviewsEnabled = UserDefaults.standard.isPreviewsEnabled
            return isPreviewsEnabled
        }
    }
    
    static var isAltJITEnabled: Bool {
        get {
            let isAltJITEnabled = UserDefaults.standard.isAltJITEnabled
            return isAltJITEnabled
        }
        set {
            UserDefaults.standard.isAltJITEnabled = newValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isAltJITEnabled])
        }
    }
    
    static var respectSilentMode: Bool {
        get {
            let respectSilentMode = UserDefaults.standard.respectSilentMode
            return respectSilentMode
        }
        set {
            UserDefaults.standard.respectSilentMode = newValue
            NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: Name.respectSilentMode])
        }
    }
    
    static func preferredCore(for gameType: GameType) -> DeltaCoreProtocol?
    {
        let key = self.preferredCoreSettingsKey(for: gameType)
        
        let identifier = UserDefaults.standard.string(forKey: key)
        
        let core = System.allCores.first { $0.identifier == identifier }
        return core
    }
    
    static func setPreferredCore(_ core: DeltaCoreProtocol, for gameType: GameType)
    {
        Delta.register(core)
        
        let key = self.preferredCoreSettingsKey(for: gameType)
        
        UserDefaults.standard.set(core.identifier, forKey: key)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil, userInfo: [NotificationUserInfoKey.name: key, NotificationUserInfoKey.core: core])
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
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin?, for system: System, traits: DeltaCore.ControllerSkin.Traits)
    {
        guard let userDefaultKey = self.preferredControllerSkinKey(for: system, traits: traits) else { return }
        
        guard UserDefaults.standard.string(forKey: userDefaultKey) != controllerSkin?.identifier else { return }
        
        UserDefaults.standard.set(controllerSkin?.identifier, forKey: userDefaultKey)
        
        NotificationCenter.default.post(name: .settingsDidChange, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.system: system, NotificationUserInfoKey.traits: traits])
    }
    
    static func preferredControllerSkin(for game: Game, traits: DeltaCore.ControllerSkin.Traits) -> ControllerSkin?
    {
        let preferredControllerSkin: ControllerSkin?
        
        switch traits.orientation
        {
        case .portrait: preferredControllerSkin = game.preferredPortraitSkin
        case .landscape: preferredControllerSkin = game.preferredLandscapeSkin
        }
        
        if let controllerSkin = preferredControllerSkin, let _ = controllerSkin.supportedTraits(for: traits)
        {
            // Check if there are supported traits, which includes fallback traits for X <-> non-X devices.
            return controllerSkin
        }
        
        if let system = System(gameType: game.type)
        {
            // Fall back to using preferred controller skin for the system.
            let controllerSkin = Settings.preferredControllerSkin(for: system, traits: traits)
            return controllerSkin
        }
                
        return nil
    }
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin?, for game: Game, traits: DeltaCore.ControllerSkin.Traits)
    {
        let context = DatabaseManager.shared.newBackgroundContext()
        context.performAndWait {
            let game = context.object(with: game.objectID) as! Game
            
            let skin: ControllerSkin?
            if let controllerSkin = controllerSkin, let contextSkin = context.object(with: controllerSkin.objectID) as? ControllerSkin
            {
                skin = contextSkin
            }
            else
            {
                skin = nil
            }            
            
            switch traits.orientation
            {
            case .portrait: game.preferredPortraitSkin = skin
            case .landscape: game.preferredLandscapeSkin = skin
            }
            
            context.saveWithErrorLogging()
        }
        
        game.managedObjectContext?.refresh(game, mergeChanges: false)
        
        if let system = System(gameType: game.type)
        {
            NotificationCenter.default.post(name: .settingsDidChange, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.system: system, NotificationUserInfoKey.traits: traits])
        }
    }
}

extension Settings
{
    static func preferredCoreSettingsKey(for gameType: GameType) -> String
    {
        let key = "core." + gameType.rawValue
        return key
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
        case .n64: systemName = "n64"
        case .ds: systemName = "ds"
        case .genesis: systemName = "genesis"
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
    
    @NSManaged var syncingService: String?
    
    @NSManaged var isButtonHapticFeedbackEnabled: Bool
    @NSManaged var isThumbstickHapticFeedbackEnabled: Bool
    
    @NSManaged var sortSaveStatesByOldestFirst: Bool
    
    @NSManaged var isPreviewsEnabled: Bool
    
    @NSManaged var isAltJITEnabled: Bool
    
    @NSManaged var respectSilentMode: Bool
}
