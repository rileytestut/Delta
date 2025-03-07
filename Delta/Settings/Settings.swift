//
//  Settings.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import DeltaFeatures
import MelonDSDeltaCore

import Roxas

extension Settings.NotificationUserInfoKey
{
    static let system: Settings.NotificationUserInfoKey = "system"
    static let traits: Settings.NotificationUserInfoKey = "traits"
    static let core: Settings.NotificationUserInfoKey = "core"
}

extension Settings.Name
{
    static let localControllerPlayerIndex: Settings.Name = "localControllerPlayerIndex"
    static let translucentControllerSkinOpacity: Settings.Name = "translucentControllerSkinOpacity"
    static let preferredControllerSkin: Settings.Name = "preferredControllerSkin"
    static let syncingService: Settings.Name = "syncingService"
    static let isButtonHapticFeedbackEnabled: Settings.Name = "isButtonHapticFeedbackEnabled"
    static let isThumbstickHapticFeedbackEnabled: Settings.Name = "isThumbstickHapticFeedbackEnabled"
    static let isAltJITEnabled: Settings.Name = "isAltJITEnabled"
    static let respectSilentMode: Settings.Name = "respectSilentMode"
    static let pauseWhileInactive: Settings.Name = "pauseWhileInactive"
    static let supportsExternalDisplays: Settings.Name = "supportsExternalDisplays"
    static let isQuickGesturesEnabled: Settings.Name = "isQuickGesturesEnabled"
    static let preferredWFCServer: Settings.Name = "preferredWFCServer"
    static let customWFCServer: Settings.Name = "customWFCServer"
}

extension Settings
{
    enum GameShortcutsMode: String
    {
        case recent
        case manual
    }
    
    typealias Name = SettingsName
    typealias NotificationUserInfoKey = SettingsUserInfoKey
    
    static let didChangeNotification = Notification.Name.settingsDidChange
}

struct Settings
{
    static let features = Features.shared
    
    static func registerDefaults()
    {
        var defaults = [#keyPath(UserDefaults.translucentControllerSkinOpacity): 0.7,
                        #keyPath(UserDefaults.gameShortcutsMode): GameShortcutsMode.recent.rawValue,
                        #keyPath(UserDefaults.isButtonHapticFeedbackEnabled): true,
                        #keyPath(UserDefaults.isThumbstickHapticFeedbackEnabled): true,
                        #keyPath(UserDefaults.sortSaveStatesByOldestFirst): true,
                        #keyPath(UserDefaults.isPreviewsEnabled): true,
                        #keyPath(UserDefaults.isAltJITEnabled): false,
                        #keyPath(UserDefaults.respectSilentMode): false,
                        #keyPath(UserDefaults.pauseWhileInactive): true,
                        #keyPath(UserDefaults.supportsExternalDisplays): true,
                        #keyPath(UserDefaults.isQuickGesturesEnabled): true,
                        Settings.preferredCoreSettingsKey(for: .ds): MelonDS.core.identifier] as [String : Any]
        
        #if BETA
        
        defaults[ExperimentalFeatures.shared.openGLES3.settingsKey.rawValue] = true
        defaults[ExperimentalFeatures.shared.dsOnlineMultiplayer.settingsKey.rawValue] = true
        
        #else
        // Manually set MelonDS as preferred DS core in case DeSmuME is cached from a previous version.
        UserDefaults.standard.set(MelonDS.core.identifier, forKey: Settings.preferredCoreSettingsKey(for: .ds))
        
        // Manually disable AltJIT for public builds.
        UserDefaults.standard.isAltJITEnabled = false
        #endif
        
        UserDefaults.standard.register(defaults: defaults)
        
        if ExperimentalFeatures.shared.repairDatabase.isEnabled
        {
            UserDefaults.standard.shouldRepairDatabase = true
            ExperimentalFeatures.shared.repairDatabase.isEnabled = false // Disable so we only repair database once.
        }
    }
}

extension Settings
{
    /// Controllers
    static var localControllerPlayerIndex: Int? = 0 {
        didSet {
            guard self.localControllerPlayerIndex != oldValue else { return }
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.localControllerPlayerIndex])
        }
    }
    
    static var translucentControllerSkinOpacity: CGFloat {
        set {
            guard newValue != self.translucentControllerSkinOpacity else { return }
            UserDefaults.standard.translucentControllerSkinOpacity = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.translucentControllerSkinOpacity])
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
            
            let shortcuts = newValue.map { UIApplicationShortcutItem(localizedTitle: $0.name, action: .launchGame(identifier: $0.identifier, userActivity: nil)) }
            
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
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.syncingService])
        }
    }
    
    static var isButtonHapticFeedbackEnabled: Bool {
        get {
            let isEnabled = UserDefaults.standard.isButtonHapticFeedbackEnabled
            return isEnabled
        }
        set {
            UserDefaults.standard.isButtonHapticFeedbackEnabled = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isButtonHapticFeedbackEnabled])
        }
    }
    
    static var isThumbstickHapticFeedbackEnabled: Bool {
        get {
            let isEnabled = UserDefaults.standard.isThumbstickHapticFeedbackEnabled
            return isEnabled
        }
        set {
            UserDefaults.standard.isThumbstickHapticFeedbackEnabled = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isThumbstickHapticFeedbackEnabled])
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
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isAltJITEnabled])
        }
    }
    
    static var respectSilentMode: Bool {
        get {
            let respectSilentMode = UserDefaults.standard.respectSilentMode
            return respectSilentMode
        }
        set {
            UserDefaults.standard.respectSilentMode = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.respectSilentMode])
        }
    }
    
    static var pauseWhileInactive: Bool {
        get {
            let pauseWhileInactive = UserDefaults.standard.pauseWhileInactive
            return pauseWhileInactive
        }
        set {
            UserDefaults.standard.pauseWhileInactive = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.pauseWhileInactive])
        }
    }
    
    static var supportsExternalDisplays: Bool {
        get {
            let supportsExternalDisplays = UserDefaults.standard.supportsExternalDisplays
            return supportsExternalDisplays
        }
        set {
            UserDefaults.standard.supportsExternalDisplays = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.supportsExternalDisplays])
        }
    }
    
    static var isQuickGesturesEnabled: Bool {
        get {
            let isQuickGesturesEnabled = UserDefaults.standard.isQuickGesturesEnabled
            return isQuickGesturesEnabled
        }
        set {
            UserDefaults.standard.isQuickGesturesEnabled = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.isQuickGesturesEnabled])
        }
    }
    
    static var preferredWFCServer: String? {
        get { UserDefaults.standard.preferredWFCServer }
        set {
            UserDefaults.standard.preferredWFCServer = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.preferredWFCServer])
        }
    }
    
    static var customWFCServer: String? {
        get { UserDefaults.standard.customWFCServer }
        set {
            UserDefaults.standard.customWFCServer = newValue
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: Name.customWFCServer])
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
        NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil, userInfo: [NotificationUserInfoKey.name: key, NotificationUserInfoKey.core: core])
    }
    
    static func preferredControllerSkin(for system: System, traits: DeltaCore.ControllerSkin.Traits, forExternalController isForExternalController: Bool) -> ControllerSkin?
    {
        if !ExperimentalFeatures.shared.airPlaySkins.isEnabled
        {
            // AirPlay skins are not supported if the feature is disabled.
            guard traits.device != .tv else { return nil }
        }
        
        guard let userDefaultsKey = self.preferredControllerSkinKey(for: system, traits: traits, forExternalController: isForExternalController) else { return nil }
        
        let identifier = UserDefaults.standard.string(forKey: userDefaultsKey)
        
        do
        {
            // Attempt to load preferred controller skin if it exists
            
            let fetchRequest: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
            
            if let identifier = identifier
            {
                fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.identifier), identifier)
                
                if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first, let _ = controllerSkin.supportedTraits(for: traits)
                {
                    // Check if there are supported traits, which includes fallback traits for X <-> non-X devices (as well as iPad -> iPhone).
                    return controllerSkin
                }
            }
            
            if isForExternalController
            {
                // It's valid (and common) to return a nil skin when external controllers are connected.
                // Reset default external controller skin back to nil.
                Settings.setPreferredControllerSkin(nil, for: system, traits: traits, forExternalController: true)
                return nil
            }
            else
            {
                // Controller skin doesn't exist (or doesn't support traits) so fall back to standard controller skin
                
                fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == YES", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.isStandard))
                
                if let controllerSkin = try DatabaseManager.shared.viewContext.fetch(fetchRequest).first
                {
                    Settings.setPreferredControllerSkin(controllerSkin, for: system, traits: traits, forExternalController: false)
                    return controllerSkin
                }
            }
        }
        catch
        {
            print(error)
        }
        
        return nil
    }
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin?, for system: System, traits: DeltaCore.ControllerSkin.Traits, forExternalController isForExternalController: Bool)
    {
        guard let userDefaultKey = self.preferredControllerSkinKey(for: system, traits: traits, forExternalController: isForExternalController) else { return }
        
        guard UserDefaults.standard.string(forKey: userDefaultKey) != controllerSkin?.identifier else { return }
        
        UserDefaults.standard.set(controllerSkin?.identifier, forKey: userDefaultKey)
        
        NotificationCenter.default.post(name: Settings.didChangeNotification, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.system: system, NotificationUserInfoKey.traits: traits])
    }
    
    static func preferredControllerSkin(for game: Game, traits: DeltaCore.ControllerSkin.Traits, forExternalController isForExternalController: Bool) -> ControllerSkin?
    {
        let preferredControllerSkin: ControllerSkin?
        
        switch (traits.orientation, traits.displayType, isForExternalController)
        {
        // Split View (no external controller)
        case (.portrait, .splitView, false): preferredControllerSkin = game.preferredSplitViewPortraitSkin
        case (.landscape, .splitView, false): preferredControllerSkin = game.preferredSplitViewLandscapeSkin
            
        // Split View (external controller)
        // We currently don't support using an external controller skin when in split view,
        // so fall back to the system's preferred skin (in case we add support later).
        case (.portrait, .splitView, true): preferredControllerSkin = nil
        case (.landscape, .splitView, true): preferredControllerSkin = nil
        
        // Standard
        case (.portrait, _, false): preferredControllerSkin = game.preferredPortraitSkin
        case (.landscape, _, false): preferredControllerSkin = game.preferredLandscapeSkin
            
        // External Controller
        case (.portrait, _, true): preferredControllerSkin = game.preferredExternalControllerPortraitSkin
        case (.landscape, _, true): preferredControllerSkin = game.preferredExternalControllerLandscapeSkin
        }
        
        if let controllerSkin = preferredControllerSkin, let _ = controllerSkin.supportedTraits(for: traits)
        {
            // Check if there are supported traits, which includes fallback traits for X <-> non-X devices (as well as iPad -> iPhone).
            return controllerSkin
        }
        
        if let system = System(gameType: game.type)
        {
            // Fall back to using preferred controller skin for the system.
            let controllerSkin = Settings.preferredControllerSkin(for: system, traits: traits, forExternalController: isForExternalController)
            return controllerSkin
        }
                
        return nil
    }
    
    static func setPreferredControllerSkin(_ controllerSkin: ControllerSkin?, for game: Game, traits: DeltaCore.ControllerSkin.Traits, forExternalController isForExternalController: Bool)
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
            
            switch (traits.orientation, traits.displayType, isForExternalController)
            {
            // Split View (no external controller)
            case (.portrait, .splitView, false): game.preferredSplitViewPortraitSkin = skin
            case (.landscape, .splitView, false): game.preferredSplitViewLandscapeSkin = skin
                
            // Split View (external controller)
            // Currently, there is no way to assign a split view skin to use when an external controller is connected.
            case (.portrait, .splitView, true): break
            case (.landscape, .splitView, true): break
                
            // External Controller
            case (.portrait, _, true): game.preferredExternalControllerPortraitSkin = skin
            case (.landscape, _, true): game.preferredExternalControllerLandscapeSkin = skin
            
            // Standard
            case (.portrait, _, false): game.preferredPortraitSkin = skin
            case (.landscape, _, false): game.preferredLandscapeSkin = skin
            }
            
            context.saveWithErrorLogging()
        }
        
        game.managedObjectContext?.refresh(game, mergeChanges: false)
        
        if let system = System(gameType: game.type)
        {
            NotificationCenter.default.post(name: Settings.didChangeNotification, object: controllerSkin, userInfo: [NotificationUserInfoKey.name: Name.preferredControllerSkin, NotificationUserInfoKey.system: system, NotificationUserInfoKey.traits: traits])
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
    static func preferredControllerSkinKey(for system: System, traits: DeltaCore.ControllerSkin.Traits, forExternalController isForExternalController: Bool) -> String?
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
        
        var deviceType: String?
        switch traits.device
        {
        case .tv: deviceType = "tv"
        case .ipad, .iphone: deviceType = nil
        }
        
        var key = systemName + "-" + orientation + "-" + displayType
        
        if let deviceType
        {
            // For backwards compatibility, only append device type if it's not nil.
            key += "-" + deviceType
        }
        
        if isForExternalController
        {
            // For backwards compatibility, only append `externalcontroller` if externalController is true.
            key += "-externalcontroller"
        }
        
        key += "-controller"
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
    
    @NSManaged var pauseWhileInactive: Bool
    @NSManaged var supportsExternalDisplays: Bool
    
    @NSManaged var isQuickGesturesEnabled: Bool
    
    @NSManaged var preferredWFCServer: String?
    @NSManaged var customWFCServer: String?
}
