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

extension DatabaseManager
{
    static let didStartNotification = Notification.Name("databaseManagerDidStartNotification")
}

extension DatabaseManager
{
    enum ImportError: Error, Hashable, Equatable
    {
        case doesNotExist(URL)
        case invalid(URL)
        case unsupported(URL)
        case unknown(URL, NSError)
        case saveFailed(Set<URL>, NSError)
    }
}

final class DatabaseManager: RSTPersistentContainer
{
    static let shared = DatabaseManager()
    
    private(set) var isStarted = false
    
    private var gamesDatabase: GamesDatabase? = nil
    
    private var validationManagedObjectContext: NSManagedObjectContext?
    
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
        
        do
        {
            if !FileManager.default.fileExists(atPath: DatabaseManager.backupDirectoryURL.path)
            {
                try FileManager.default.copyItem(at: DatabaseManager.defaultDirectoryURL(), to: DatabaseManager.backupDirectoryURL)
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
        catch
        {
            completionHandler(error)
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
                guard let deltaControllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: system.gameType) else { continue }
                
                let controllerSkin = ControllerSkin(context: context)
                controllerSkin.isStandard = true
                controllerSkin.filename = deltaControllerSkin.fileURL.lastPathComponent
                
                controllerSkin.configure(with: deltaControllerSkin)
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
                if !FileManager.default.fileExists(atPath: DatabaseManager.gamesDatabaseURL.path)
                {
                    guard let bundleURL = Bundle.main.url(forResource: "openvgdb", withExtension: "sqlite") else { throw GamesDatabase.Error.doesNotExist }
                    try FileManager.default.copyItem(at: bundleURL, to: DatabaseManager.gamesDatabaseURL)
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
        var errors = Set<ImportError>()
        
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
        var errors = Set<ImportError>()
        
        self.performBackgroundTask { (context) in
            
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
        
        let artworkURL = gameURL.deletingPathExtension().appendingPathExtension("jpg")
        return artworkURL
    }
    
    class var backupDirectoryURL: URL
    {
        let backupDirectoryURL = FileManager.default.documentsDirectory.appendingPathComponent("Database-Backup")        
        return backupDirectoryURL
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
