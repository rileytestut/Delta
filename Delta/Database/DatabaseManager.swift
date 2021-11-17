//
//  DatabaseManager.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

// Workspace
import DeltaCore
import Harmony
import Roxas
import ZIPFoundation
import MelonDSDeltaCore

extension DatabaseManager
{
    static let didStartNotification = Notification.Name("databaseManagerDidStartNotification")
}

extension DatabaseManager
{
    enum ImportError: LocalizedError, Hashable, Equatable
    {
        case doesNotExist(URL)
        case invalid(URL)
        case unsupported(URL)
        case unknown(URL, NSError)
        case saveFailed(Set<URL>, NSError)
        
        var errorDescription: String? {
            switch self
            {
            case .doesNotExist: return NSLocalizedString("The file does not exist.", comment: "")
            case .invalid: return NSLocalizedString("The file is invalid.", comment: "")
            case .unsupported: return NSLocalizedString("This file is not supported.", comment: "")
            case .unknown(_, let error): return error.localizedDescription
            case .saveFailed(_, let error): return error.localizedDescription
            }
        }
    }
}

final class DatabaseManager: RSTPersistentContainer
{
    static let shared = DatabaseManager()
    
    private(set) var isStarted = false
    
    private var gamesDatabase: GamesDatabase? = nil
    
    private var validationManagedObjectContext: NSManagedObjectContext?
    
    private let importController = ImportController(documentTypes: [])
    
    private init()
    {
        guard
            let modelURL = Bundle(for: DatabaseManager.self).url(forResource: "Delta", withExtension: "momd"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL),
            let harmonyModel = NSManagedObjectModel.harmonyModel(byMergingWith: [managedObjectModel])
        else { fatalError("Core Data model cannot be found. Aborting.") }
        
        super.init(name: "Delta", managedObjectModel: harmonyModel)
        
        self.shouldAddStoresAsynchronously = true
    }
}

extension DatabaseManager
{
    func start(completionHandler: @escaping (Error?) -> Void)
    {
        guard !self.isStarted else { return }
        
        for description in self.persistentStoreDescriptions
        {
            // Set configuration so RSTPersistentContainer can determine how to migrate this and Harmony's database independently.
            description.configuration = NSManagedObjectModel.Configuration.external.rawValue
        }
        
        self.loadPersistentStores { (description, error) in
            guard error == nil else { return completionHandler(error) }
            
            self.prepareDatabase {
                self.isStarted = true
                
                NotificationCenter.default.post(name: DatabaseManager.didStartNotification, object: self)
                
                completionHandler(nil)
            }
        }
    }
    
    func prepare(_ core: DeltaCoreProtocol, in context: NSManagedObjectContext)
    {
        guard let system = System(gameType: core.gameType) else { return }
        
        if let skin = ControllerSkin(system: system, context: context)
        {
            print("Updated default skin (\(skin.identifier)) for system:", system)
        }
        else
        {
            print("Failed to update default skin for system:", system)
        }
        
        switch system
        {
        case .ds where core == MelonDS.core:
            
            // Returns nil if game already exists.
            func makeBIOS(name: String, identifier: String) -> Game?
            {
                let predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), identifier)
                if let _ = Game.instancesWithPredicate(predicate, inManagedObjectContext: context, type: Game.self).first
                {
                    // BIOS already exists, so don't do anything.
                    return nil
                }
                
                let filename: String
                
                switch identifier
                {
                case Game.melonDSBIOSIdentifier:
                    guard
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios7URL.path) &&
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios9URL.path) &&
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path)
                    else { return nil }
                    
                    filename = "nds.bios"
                    
                case Game.melonDSDSiBIOSIdentifier:
                    #if BETA
                    
                    guard
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiBIOS7URL.path) &&
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiBIOS9URL.path) &&
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiFirmwareURL.path) &&
                        FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiNANDURL.path)
                    else { return nil }
                    
                    filename = "dsi.bios"
                    
                    #else
                    return nil
                    #endif
                
                default: filename = "system.bios"
                }
                
                let bios = Game(context: context)
                bios.name = name
                bios.identifier = identifier
                bios.type = .ds
                bios.filename = filename
                
                if let artwork = UIImage(named: "DS Home Screen"), let artworkData = artwork.pngData()
                {
                    do
                    {
                        let destinationURL = DatabaseManager.artworkURL(for: bios)
                        try artworkData.write(to: destinationURL, options: .atomic)
                        bios.artworkURL = destinationURL
                    }
                    catch
                    {
                        print("Failed to copy default DS home screen artwork.", error)
                    }
                }
                
                return bios
            }
            
            let insertedGames = [
                (name: NSLocalizedString("Home Screen", comment: ""), identifier: Game.melonDSBIOSIdentifier),
                (name: NSLocalizedString("Home Screen (DSi)", comment: ""), identifier: Game.melonDSDSiBIOSIdentifier)
            ].compactMap(makeBIOS)
            
            // Break if we didn't create any new Games.
            guard !insertedGames.isEmpty else { break }
            
            let gameCollection = GameCollection(context: context)
            gameCollection.identifier = GameType.ds.rawValue
            gameCollection.index = Int16(System.ds.year)
            gameCollection.games.formUnion(insertedGames)
            
        case .ds:
            let predicate = NSPredicate(format: "%K IN %@", #keyPath(Game.identifier), [Game.melonDSBIOSIdentifier, Game.melonDSDSiBIOSIdentifier])
            
            let games = Game.instancesWithPredicate(predicate, inManagedObjectContext: context, type: Game.self)
            for game in games
            {
                context.delete(game)
            }
            
        default: break
        }
    }
}

//MARK: - Update -
private extension DatabaseManager
{
    func updateRecentGameShortcuts()
    {
        guard let managedObjectContext = self.validationManagedObjectContext else { return }
        
        guard Settings.gameShortcutsMode == .recent else { return }
        
        let fetchRequest = Game.recentlyPlayedFetchRequest
        fetchRequest.returnsObjectsAsFaults = false
        
        do
        {
            let games = try managedObjectContext.fetch(fetchRequest)
            Settings.gameShortcuts = games
        }
        catch
        {
            print(error)
        }
    }
}

//MARK: - Preparation -
private extension DatabaseManager
{
    func prepareDatabase(completion: @escaping () -> Void)
    {
        self.validationManagedObjectContext = self.newBackgroundContext()
        
        NotificationCenter.default.addObserver(self, selector: #selector(DatabaseManager.validateManagedObjectContextSave(with:)), name: .NSManagedObjectContextDidSave, object: nil)
        
        self.performBackgroundTask { (context) in
            
            for system in System.allCases
            {
                self.prepare(system.deltaCore, in: context)
            }
            
            do
            {
                try context.save()
            }
            catch
            {
                print("Failed to import standard controller skins:", error)
            }
            
            do
            {                
                if !FileManager.default.fileExists(atPath: DatabaseManager.gamesDatabaseURL.path) || GamesDatabase.version != GamesDatabase.previousVersion
                {
                    guard let bundleURL = Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite") else { throw GamesDatabase.Error.doesNotExist }
                    try FileManager.default.copyItem(at: bundleURL, to: DatabaseManager.gamesDatabaseURL, shouldReplace: true)
                }
                
                self.gamesDatabase = try GamesDatabase()
            }
            catch
            {
                print(error)
            }
            
            completion()
        }
    }
}

//MARK: - Importing -
/// Importing
extension DatabaseManager
{
    func importGames(at urls: Set<URL>, completion: ((Set<Game>, Set<ImportError>) -> Void)?)
    {
        let externalFileURLs = urls.filter { !FileManager.default.isReadableFile(atPath: $0.path) }
        guard externalFileURLs.isEmpty else {
            self.importExternalFiles(at: externalFileURLs) { (importedURLs, externalImportErrors) in
                var availableFileURLs = urls.filter { !externalFileURLs.contains($0) }
                availableFileURLs.formUnion(importedURLs)
                
                self.importGames(at: Set(availableFileURLs)) { (importedGames, importErrors) in
                    let allErrors = importErrors.union(externalImportErrors)
                    completion?(importedGames, allErrors)
                }
            }
            
            return
        }
        
        let zipFileURLs = urls.filter { $0.pathExtension.lowercased() == "zip" }
        if zipFileURLs.count > 0
        {
            self.extractCompressedGames(at: Set(zipFileURLs)) { (extractedURLs, extractErrors) in
                let gameURLs = urls.filter { $0.pathExtension.lowercased() != "zip" } + extractedURLs
                self.importGames(at: Set(gameURLs)) { (importedGames, importErrors) in
                    let allErrors = importErrors.union(extractErrors)
                    completion?(importedGames, allErrors)
                }
            }
            
            return
        }
        
        self.performBackgroundTask { (context) in
            
            var errors = Set<ImportError>()
            var identifiers = Set<String>()
            
            for url in urls
            {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    errors.insert(.doesNotExist(url))
                    continue
                }
                
                guard let gameType = GameType(fileExtension: url.pathExtension), let system = System(gameType: gameType) else {
                    errors.insert(.unsupported(url))
                    continue
                }
                
                guard System.registeredSystems.contains(system) else {
                    errors.insert(.unsupported(url))
                    continue
                }
                
                let identifier: String
                
                do
                {
                    identifier = try RSTHasher.sha1HashOfFile(at: url)
                }
                catch let error as NSError
                {
                    errors.insert(.unknown(url, error))
                    continue
                }
                
                let filename = identifier + "." + url.pathExtension
                
                let game = Game(context: context)
                game.identifier = identifier
                game.type = gameType
                game.filename = filename
                
                let databaseMetadata = self.gamesDatabase?.metadata(for: game)
                game.name = databaseMetadata?.name ?? url.deletingPathExtension().lastPathComponent
                game.artworkURL = databaseMetadata?.artworkURL
                
                let gameCollection = GameCollection(context: context)
                gameCollection.identifier = gameType.rawValue
                gameCollection.index = Int16(system.year)
                gameCollection.games.insert(game)
                
                do
                {
                    let destinationURL = DatabaseManager.gamesDirectoryURL.appendingPathComponent(filename)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path)
                    {
                        // Game already exists, so we choose not to override it and just delete the new game instead
                        try FileManager.default.removeItem(at: url)
                    }
                    else
                    {
                        try FileManager.default.moveItem(at: url, to: destinationURL)
                    }
                    
                    identifiers.insert(game.identifier)
                }
                catch let error as NSError
                {
                    print("Import Games error:", error)
                    game.managedObjectContext?.delete(game)
                    
                    errors.insert(.unknown(url, error))
                }
            }

            do
            {
                try context.save()
            }
            catch let error as NSError
            {
                print("Failed to save import context:", error)
                
                identifiers.removeAll()
                
                errors.insert(.saveFailed(urls, error))
            }
            
            DatabaseManager.shared.viewContext.perform {
                let predicate = NSPredicate(format: "%K IN (%@)", #keyPath(Game.identifier), identifiers)
                let games = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self)
                completion?(Set(games), errors)
            }
        }
    }
    
    func importControllerSkins(at urls: Set<URL>, completion: ((Set<ControllerSkin>, Set<ImportError>) -> Void)?)
    {
        let externalFileURLs = urls.filter { !FileManager.default.isReadableFile(atPath: $0.path) }
        guard externalFileURLs.isEmpty else {
            self.importExternalFiles(at: externalFileURLs) { (importedURLs, externalImportErrors) in
                var availableFileURLs = urls.filter { !externalFileURLs.contains($0) }
                availableFileURLs.formUnion(importedURLs)
                
                self.importControllerSkins(at: Set(availableFileURLs)) { (importedSkins, importErrors) in
                    let allErrors = importErrors.union(externalImportErrors)
                    completion?(importedSkins, allErrors)
                }
            }
            
            return
        }
        
        self.performBackgroundTask { (context) in
            
            var errors = Set<ImportError>()
            var identifiers = Set<String>()
            
            for url in urls
            {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    errors.insert(.doesNotExist(url))
                    continue
                }
                
                guard let deltaControllerSkin = DeltaCore.ControllerSkin(fileURL: url) else {
                    errors.insert(.invalid(url))
                    continue
                }
                
                let controllerSkin = ControllerSkin(context: context)
                controllerSkin.filename = deltaControllerSkin.identifier + ".deltaskin"
                
                controllerSkin.configure(with: deltaControllerSkin)
                                
                do
                {
                    if FileManager.default.fileExists(atPath: controllerSkin.fileURL.path)
                    {
                        // Normally we'd replace item instead of delete + move, but it's crashing as of iOS 10
                        // FileManager.default.replaceItemAt(controllerSkin.fileURL, withItemAt: url)
                        
                        // Controller skin exists, but we replace it with the new skin
                        try FileManager.default.removeItem(at: controllerSkin.fileURL)
                    }
                    
                    try FileManager.default.moveItem(at: url, to: controllerSkin.fileURL)
                    
                    identifiers.insert(controllerSkin.identifier)
                }
                catch let error as NSError
                {
                    print("Import Controller Skins error:", error)
                    controllerSkin.managedObjectContext?.delete(controllerSkin)
                    
                    errors.insert(.unknown(url, error))
                }
            }
            
            do
            {
                try context.save()
            }
            catch let error as NSError
            {
                print("Failed to save controller skin import context:", error)
                
                identifiers.removeAll()
                
                errors.insert(.saveFailed(urls, error))
            }
            
            DatabaseManager.shared.viewContext.perform {
                let predicate = NSPredicate(format: "%K IN (%@)", #keyPath(Game.identifier), identifiers)
                let controllerSkins = ControllerSkin.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: ControllerSkin.self)
                completion?(Set(controllerSkins), errors)
            }
        }
    }
    
    private func extractCompressedGames(at urls: Set<URL>, completion: @escaping ((Set<URL>, Set<ImportError>) -> Void))
    {
        DispatchQueue.global().async {
            
            var outputURLs = Set<URL>()
            var errors = Set<ImportError>()
            
            for url in urls
            {
                var archiveContainsValidGameFile = false
                
                guard let archive = Archive(url: url, accessMode: .read) else {
                    errors.insert(.invalid(url))
                    continue
                }
                
                for entry in archive
                {
                    do
                    {
                        // Ensure entry is not in a subdirectory
                        guard !entry.path.contains("/") else { continue }
                        
                        let fileExtension = (entry.path as NSString).pathExtension
                        
                        guard GameType(fileExtension: fileExtension) != nil else { continue }
                        
                        // At least one entry is a valid game file, so we set archiveContainsValidGameFile to true
                        // This will result in this archive being considered valid, and thus we will not return an ImportError.invalid error for the archive
                        // However, if this game file does turn out to be invalid when extracting, we'll return an ImportError.invalid error specific to this game file
                        archiveContainsValidGameFile = true
                        
                        // Must use temporary directory, and not the directory containing zip file, since the latter might be read-only (such as when importing from Safari)
                        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(entry.path)
                        
                        if FileManager.default.fileExists(atPath: outputURL.path)
                        {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                        
                        _ = try archive.extract(entry, to: outputURL)
                        
                        outputURLs.insert(outputURL)
                    }
                    catch
                    {
                        print(error)
                    }
                }
                
                if !archiveContainsValidGameFile
                {
                    errors.insert(.invalid(url))
                }
            }
            
            for url in urls
            {
                if FileManager.default.fileExists(atPath: url.path)
                {
                    do
                    {
                        try FileManager.default.removeItem(at: url)
                    }
                    catch
                    {
                        print(error)
                    }
                }
            }
            
            completion(outputURLs, errors)
        }
    }
    
    private func importExternalFiles(at urls: Set<URL>, completion: @escaping ((Set<URL>, Set<ImportError>) -> Void))
    {
        var outputURLs = Set<URL>()
        var errors = Set<ImportError>()
        
        let dispatchGroup = DispatchGroup()
        for url in urls
        {
            dispatchGroup.enter()
            
            self.importController.importExternalFile(at: url) { (result) in
                switch result
                {
                case .failure(let error): errors.insert(.unknown(url, error as NSError))
                case .success(let fileURL): outputURLs.insert(fileURL)
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .global()) {
            completion(outputURLs, errors)
        }
    }
}

//MARK: - File URLs -
/// File URLs
extension DatabaseManager
{
    override class func defaultDirectoryURL() -> URL
    {
        let documentsDirectoryURL: URL
        
        if UIDevice.current.userInterfaceIdiom == .tv
        {
            documentsDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        }
        else
        {
            documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
        let databaseDirectoryURL = documentsDirectoryURL.appendingPathComponent("Database")
        self.createDirectory(at: databaseDirectoryURL)
        
        return databaseDirectoryURL
    }
    
    class var gamesDatabaseURL: URL
    {
        let gamesDatabaseURL = self.defaultDirectoryURL().appendingPathComponent("openvgdb.sqlite")
        return gamesDatabaseURL
    }

    class var gamesDirectoryURL: URL
    {
        let gamesDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Games")
        self.createDirectory(at: gamesDirectoryURL)
        
        return gamesDirectoryURL
    }
    
    class var saveStatesDirectoryURL: URL
    {
        let saveStatesDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Save States")
        self.createDirectory(at: saveStatesDirectoryURL)
        
        return saveStatesDirectoryURL
    }
    
    class func saveStatesDirectoryURL(for game: Game) -> URL
    {
        let gameDirectoryURL = DatabaseManager.saveStatesDirectoryURL.appendingPathComponent(game.identifier)
        self.createDirectory(at: gameDirectoryURL)
        
        return gameDirectoryURL
    }
    
    class var controllerSkinsDirectoryURL: URL
    {
        let controllerSkinsDirectoryURL = DatabaseManager.defaultDirectoryURL().appendingPathComponent("Controller Skins")
        self.createDirectory(at: controllerSkinsDirectoryURL)
        
        return controllerSkinsDirectoryURL
    }
    
    class func controllerSkinsDirectoryURL(for gameType: GameType) -> URL
    {
        let gameTypeDirectoryURL = DatabaseManager.controllerSkinsDirectoryURL.appendingPathComponent(gameType.rawValue)
        self.createDirectory(at: gameTypeDirectoryURL)
        
        return gameTypeDirectoryURL
    }
    
    class func artworkURL(for game: Game) -> URL
    {
        let gameURL = game.fileURL
        
        let artworkURL = gameURL.deletingPathExtension().appendingPathExtension("png")
        return artworkURL
    }
}

//MARK: - Notifications -
private extension DatabaseManager
{
    @objc func validateManagedObjectContextSave(with notification: Notification)
    {
        guard (notification.object as? NSManagedObjectContext) != self.validationManagedObjectContext else { return }
        
        let insertedObjects = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updatedObjects = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
        let deletedObjects = (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? []
        
        let allObjects = insertedObjects.union(updatedObjects).union(deletedObjects)

        if allObjects.contains(where: { $0 is Game })
        {
            self.validationManagedObjectContext?.perform {
                self.updateRecentGameShortcuts()
            }
        }
    }
}

//MARK: - Private -
private extension DatabaseManager
{
    class func createDirectory(at url: URL)
    {
        do
        {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        catch
        {
            print(error)
        }
    }
}
