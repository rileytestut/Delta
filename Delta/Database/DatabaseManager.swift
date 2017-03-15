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
import ZipZap

// Pods
import FileMD5Hash

extension DatabaseManager
{
    enum ImportError: Error, Hashable
    {
        case doesNotExist(URL)
        case invalid(URL)
        case unknown(URL, NSError)
        case saveFailed(Set<URL>, NSError)
        
        var hashValue: Int {
            switch self
            {
            case .doesNotExist: return 0
            case .invalid: return 1
            case .unknown: return 2
            case .saveFailed: return 3
            }
        }
        
        static func ==(lhs: ImportError, rhs: ImportError) -> Bool
        {
            switch (lhs, rhs)
            {
            case (let .doesNotExist(url1), let .doesNotExist(url2)) where url1 == url2: return true
            case (let .invalid(url1), let .invalid(url2)) where url1 == url2: return true
            case (let .unknown(url1, error1), let .unknown(url2, error2)) where url1 == url2 && error1 == error2: return true
            case (let .saveFailed(urls1, error1), let .saveFailed(urls2, error2)) where urls1 == urls2 && error1 == error2: return true
            case (.doesNotExist, _): return false
            case (.invalid, _): return false
            case (.unknown, _): return false
            case (.saveFailed, _): return false
            }
        }
        
    }
}

final class DatabaseManager: NSPersistentContainer
{
    static let shared = DatabaseManager()
    
    fileprivate var gamesDatabase: GamesDatabase? = nil
    
    private init()
    {
        guard
            let modelURL = Bundle(for: DatabaseManager.self).url(forResource: "Model", withExtension: "mom"),
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else { fatalError("Core Data model cannot be found. Aborting.") }
        
        
        super.init(name: "Delta", managedObjectModel: managedObjectModel)
        
        self.viewContext.automaticallyMergesChangesFromParent = true
    }
}

extension DatabaseManager
{
    override func newBackgroundContext() -> NSManagedObjectContext
    {
        let context = super.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void)
    {
        super.loadPersistentStores { (description, error) in
            self.prepareDatabase {
                block(description, error)
            }
        }
    }
}

//MARK: - Preparation -
private extension DatabaseManager
{
    func prepareDatabase(completion: @escaping (Void) -> Void)
    {
        self.performBackgroundTask { (context) in
            
            for gameType in GameType.supportedTypes
            {
                guard let deltaControllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: gameType) else { continue }
                
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
                
                let identifier = FileHash.sha1HashOfFile(atPath: url.path) as String
                
                let filename = identifier + "." + url.pathExtension
                
                let game = Game.insertIntoManagedObjectContext(context)
                game.identifier = identifier
                game.filename = filename
                
                let databaseMetadata = self.gamesDatabase?.metadata(for: game)
                game.name = databaseMetadata?.name ?? url.deletingPathExtension().lastPathComponent
                game.artworkURL = databaseMetadata?.artworkURL
                                
                let gameCollection = GameCollection.gameSystemCollectionForPathExtension(url.pathExtension, inManagedObjectContext: context)
                game.type = GameType(rawValue: gameCollection.identifier)
                game.gameCollections.insert(gameCollection)
                
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
            
            var semaphores = Set<DispatchSemaphore>()
            var outputURLs = Set<URL>()
            var errors = Set<ImportError>()
            
            for url in urls
            {
                var archiveContainsValidGameFile = false
                
                do
                {
                    let archive = try ZZArchive(url: url)
                    
                    for entry in archive.entries
                    {
                        // Ensure entry is not in a subdirectory
                        guard !entry.fileName.contains("/") else { continue }
                        
                        let fileExtension = (entry.fileName as NSString).pathExtension
                        let gameType = GameType.gameType(forFileExtension: fileExtension)
                        
                        guard gameType != .unknown else { continue }
                        
                        // At least one entry is a valid game file, so we set archiveContainsValidGameFile to true
                        // This will result in this archive being considered valid, and thus we will not return an ImportError.invalid error for the archive
                        // However, if this game file does turn out to be invalid when extracting, we'll return an ImportError.invalid error specific to this game file
                        archiveContainsValidGameFile = true
                        
                        // ROMs may potentially be very large, so we extract using file streams and not raw Data
                        let inputStream = try entry.newStream()
                        
                        // Must use temporary directory, and not the directory containing zip file, since the latter might be read-only (such as when importing from Safari)
                        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(entry.fileName)
                        
                        if FileManager.default.fileExists(atPath: outputURL.path)
                        {
                            try FileManager.default.removeItem(at: outputURL)
                        }
                        
                        guard let outputStream = OutputStream(url: outputURL, append: false) else { continue }
                        
                        let semaphore = DispatchSemaphore(value: 0)
                        semaphores.insert(semaphore)
                        
                        let outputWriter = InputStreamOutputWriter(inputStream: inputStream, outputStream: outputStream)
                        outputWriter.start { (error) in
                            if let error = error
                            {
                                if FileManager.default.fileExists(atPath: outputURL.path)
                                {
                                    do
                                    {
                                        try FileManager.default.removeItem(at: outputURL)
                                    }
                                    catch
                                    {
                                        print(error)
                                    }
                                }
                                
                                print(error)
                                
                                errors.insert(.invalid(outputURL))
                            }
                            else
                            {
                                outputURLs.insert(outputURL)
                            }
                            
                            semaphore.signal()
                        }
                    }
                }
                catch
                {
                    print(error)
                }
                
                if !archiveContainsValidGameFile
                {
                    errors.insert(.invalid(url))
                }
            }
            
            for semaphore in semaphores
            {
                semaphore.wait()
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
