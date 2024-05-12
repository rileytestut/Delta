//
//  RepairDatabaseViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/4/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import OSLog

import DeltaCore

import Roxas
import Harmony

private extension String
{
    func sanitizedFilePath() -> String
    {
        let sanitizedFilePath = self.components(separatedBy: .urlFilenameAllowed.inverted).joined()
        return sanitizedFilePath
    }
}

class RepairDatabaseViewController: UIViewController
{
    var completionHandler: (() -> Void)?
    
    private var _viewDidAppear = false
    
    private lazy var managedObjectContext = DatabaseManager.shared.newBackgroundSavingViewContext()
    private lazy var gameSavesContext = DatabaseManager.shared.newBackgroundContext(withParent: self.managedObjectContext)
    
    private var gamesByID: [String: Game]?
    
    private lazy var backupsDirectory = FileManager.default.documentsDirectory.appendingPathComponent("Backups")
    private lazy var gameSavesDirectory = DatabaseManager.gamesDirectoryURL
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = .systemBackground
        
        self.isModalInPresentation = true
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("Verifying Database…", comment: "")
        placeholderView.detailTextLabel.text = nil
        placeholderView.activityIndicatorView.startAnimating()
        placeholderView.stackView.spacing = 15
        self.view.addSubview(placeholderView, pinningEdgesWith: .zero)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if !_viewDidAppear
        {
            self.repairDatabase()
        }
        
        _viewDidAppear = true
    }
}

private extension RepairDatabaseViewController
{
    func repairDatabase()
    {
        Logger.database.info("Begin repairing database...")
        
        self.repairGames { result in
            switch result
            {
            case .failure(let error):
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Unable to Repair Games", error: error)
                    self.present(alertController, animated: true)
                }
                
            case .success:
                self.repairGameSaves { result in
                    DispatchQueue.main.async {
                        switch result
                        {
                        case .failure(let error):
                            let alertController = UIAlertController(title: "Unable to Repair Save Files", error: error)
                            self.present(alertController, animated: true)
                            
                        case .success:
                            self.showReviewViewController()
                        }
                    }
                }
            }
        }
    }
    
    func repairGames(completion: @escaping (Result<Void, Error>) -> Void)
    {
        self.managedObjectContext.perform {
            do
            {
                let fetchRequest = Game.fetchRequest()
                fetchRequest.propertiesToFetch = [#keyPath(Game.type)]
                fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(Game.gameCollection)]
                
                let allGames = try self.managedObjectContext.fetch(fetchRequest)
                let affectedGames = allGames.filter { $0.type.rawValue != $0.gameCollection?.identifier }
                
                let gameCollections = try self.managedObjectContext.fetch(GameCollection.fetchRequest())
                let gameCollectionsByID = gameCollections.reduce(into: [:]) { $0[$1.identifier] = $1 }
                
                for game in affectedGames
                {
                    let gameCollection = gameCollectionsByID[game.type.rawValue]
                    game.gameCollection = gameCollection
                    
                    Logger.database.notice("Re-associating “\(game.name, privacy: .public)” with GameCollection: \(gameCollection?.identifier ?? "nil", privacy: .public)")
                }
                
                try self.managedObjectContext.save()
                
                completion(.success)
            }
            catch
            {
                completion(.failure(error))
            }
        }
    }
    
    func repairGameSaves(completion: @escaping (Result<Void, Error>) -> Void)
    {
        self.managedObjectContext.perform {
            do
            {
                // Fetch GameSaves that don't have same identifier as their Game,
                // OR GameSaves that have a non-nil SHA1 hash.
                //
                // This covers GameSaves connected to wrong games and GameSaves with nil Games,
                // as well as any GameSaves modified since last beta (which we assume are corrupted).
                
                let fetchRequest = GameSave.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "(%K == nil) OR (%K != %K) OR (%K != nil)",
                                                     #keyPath(GameSave.game),
                                                     #keyPath(GameSave.identifier), #keyPath(GameSave.game.identifier),
                                                     #keyPath(GameSave.sha1))
                
                let gameSaves = try self.managedObjectContext.fetch(fetchRequest)
                let gameSavesByID = gameSaves.reduce(into: [:]) { $0[$1.identifier] = $1 }
                
                let gamesFetchRequest = Game.fetchRequest()
                gamesFetchRequest.predicate = NSPredicate(format: "%K IN %@", #keyPath(Game.identifier), Set(gameSavesByID.keys))
                
                let games = try self.managedObjectContext.fetch(gamesFetchRequest)
                self.gamesByID = games.reduce(into: [:]) { $0[$1.identifier] = $1 }
                
                let savesBackupsDirectory = self.backupsDirectory.appendingPathComponent("Saves")
                try FileManager.default.createDirectory(at: savesBackupsDirectory, withIntermediateDirectories: true)
                
                var conflictedGames = Set<Game>()
                
                for gameSave in gameSaves
                {
                    let expectedGame = self.repair(gameSave, backupsDirectory: savesBackupsDirectory)
                    
                    // At this point, gameSave is only updated in gameSavesContext,
                    // so gameSave here still points to previous game,
                    
                    if let game = gameSave.game
                    {
                        Logger.database.notice("The save file for “\(game.name, privacy: .public)” is potentially corrupted, writing to conflicts.txt")
                        conflictedGames.insert(game)
                    }
                    
                    if let expectedGame
                    {
                        Logger.database.notice("The save file for “\(expectedGame.name, privacy: .public)” is potentially corrupted, writing to conflicts.txt")
                        conflictedGames.insert(expectedGame)
                    }
                }
                
                try self.gameSavesContext.performAndWait {
                    try self.gameSavesContext.save()
                }
                
                try self.managedObjectContext.save()
                
                let outputURL = self.backupsDirectory.appendingPathComponent("conflicts.txt")
                
                let conflictsLog = conflictedGames.map { $0.name + " (" + $0.identifier + ")" }.sorted().joined(separator: "\n")
                try conflictsLog.write(to: outputURL, atomically: true, encoding: .utf8)
                
                completion(.success)
            }
            catch
            {
                completion(.failure(error))
            }
        }
    }
    
    // Returns expectedGame, but in managedObjectContext (not gameSavesContext)
    func repair(_ gameSave: GameSave, backupsDirectory: URL) -> Game?
    {
        Logger.database.notice("Repairing GameSave \(gameSave.identifier, privacy: .public)...")
        
        guard let expectedGame = self.gamesByID?[gameSave.identifier] else {
            // Game doesn't exist, so we'll back up save file and delete record.
            
            Logger.database.warning("Orphaning GameSave \(gameSave.identifier, privacy: .public) due to no matching game.")
            
            do
            {
                try self.backup(gameSave, for: nil, to: backupsDirectory)
            }
            catch
            {
                Logger.database.error("Failed to back up save file for orphaned GameSave \(gameSave.identifier, privacy: .public). \(error, privacy: .public)")
            }
            
            self.gameSavesContext.performAndWait {
                let gameSave = self.gameSavesContext.object(with: gameSave.objectID) as! GameSave
                gameSave.game = nil
            }
            
            return nil
        }
        
        let misplacedGameSave: GameSave?
        if let otherGameSave = expectedGame.gameSave, otherGameSave != gameSave
        {
            misplacedGameSave = otherGameSave
            
            Logger.database.info("GameSave \(gameSave.identifier, privacy: .public) will misplace \(otherGameSave.identifier, privacy: .public)")
        }
        else
        {
            misplacedGameSave = nil
        }
        
        do
        {
            // Back up the save file gameSave (incorrectly) refers to, but name it after the _expected_ game.
            try self.backup(gameSave, for: expectedGame, to: backupsDirectory)
        }
        catch
        {
            Logger.database.error("Failed to back up save file for GameSave \(gameSave.identifier, privacy: .public). Expected Game: \(expectedGame.identifier). \(error, privacy: .public)")
        }
        
        // Ignore error if we can't hash file, not that big a deal.
        let hash = try? RSTHasher.sha1HashOfFile(at: expectedGame.gameSaveURL)
        
        // Make changes on separate context so we don't change any relationships until we're finished.
        // This allows us to refer to previous relationships.
        self.gameSavesContext.performAndWait {
            let gameSave = self.gameSavesContext.object(with: gameSave.objectID) as! GameSave
            let expectedGame = self.gameSavesContext.object(with: expectedGame.objectID) as! Game
            let misplacedGameSave: GameSave? = misplacedGameSave.map { self.gameSavesContext.object(with: $0.objectID) as! GameSave }
            
            if hash == gameSave.sha1
            {
                // .sav has same hash as GameSave SHA1,
                // so we can relink without changes.
                
                Logger.database.info("GameSave \(gameSave.identifier, privacy: .public)'s hash matches .sav, relinking without changes.")
            }
            else if let misplacedGameSave
            {
                // GameSave data differs from actual .sav file,
                // so copy metadata from misplacedGameSave.
                
                Logger.database.info("GameSave \(gameSave.identifier, privacy: .public)'s hash does NOT match .sav, ignoring misplaced GameSave \(misplacedGameSave.identifier, privacy: .public).")
                
                // Not worth potential conflicts.
                // gameSave.sha1 = misplacedGameSave.sha1
                // gameSave.modifiedDate = misplacedGameSave.modifiedDate
            }
            else
            {
                // GameSave data differs from actual .sav file,
                // so copy metadata from disk.
                Logger.database.info("GameSave \(gameSave.identifier, privacy: .public)'s hash does NOT match .sav, ignoring.")
                
                // Not worth potential conflicts.
                // let modifiedDate = try? FileManager.default.attributesOfItem(atPath: expectedGame.gameSaveURL.path)[.modificationDate] as? Date
                // gameSave.sha1 = hash
                // gameSave.modifiedDate = modifiedDate ?? Date()
            }
            
            gameSave.game = expectedGame
        }
        
        return expectedGame
    }
    
    func backup(_ gameSave: GameSave, for expectedGame: Game?, to backupsDirectory: URL) throws
    {
        Logger.database.notice("Backing up GameSave \(gameSave.identifier, privacy: .public). Expected Game: \(expectedGame?.name ?? "nil", privacy: .public)")
        
        if let game = gameSave.game
        {
            // GameSave is linked with incorrect game.
            
            // Prefer using expectedGame's saveFileExtension over game's.
            let saveFileExtension: String
            if let deltaCore = Delta.core(for: expectedGame?.type ?? game.type)
            {
                saveFileExtension = deltaCore.gameSaveFileExtension
            }
            else
            {
                saveFileExtension = "sav"
            }
            
            // 1. Backup existing file at `game`'s expected save file location
            if FileManager.default.fileExists(atPath: game.gameSaveURL.path)
            {
                // Filename = expectedGame.name? + game.identifier
                
                let filename: String
                if let expectedGame
                {
                    filename = expectedGame.name + "_" + game.identifier
                }
                else
                {
                    filename = game.identifier
                }
                
                let sanitizedFilename = filename.sanitizedFilePath()
                
                let destinationURL = backupsDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension(saveFileExtension)
                try FileManager.default.copyItem(at: game.gameSaveURL, to: destinationURL, shouldReplace: true)
                
                Logger.database.notice("Backed up save file \(game.gameSaveURL.lastPathComponent, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
                
                let rtcFileURL = game.gameSaveURL.deletingPathExtension().appendingPathExtension("rtc")
                if FileManager.default.fileExists(atPath: rtcFileURL.path)
                {
                    let destinationURL = backupsDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension("rtc")
                    try FileManager.default.copyItem(at: rtcFileURL, to: destinationURL, shouldReplace: true)
                    
                    Logger.database.notice("Backed up RTC save file \(rtcFileURL.lastPathComponent, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
                }
            }
            
            // 2. Backup existing file at `expectedGame`'s save file location
            if let expectedGame, FileManager.default.fileExists(atPath: expectedGame.gameSaveURL.path)
            {
                // Filename = expectedGame.name + (misplacedGameSave.identifier ?? expectedGame.identifier)
                
                let filename = expectedGame.name + "_" + (expectedGame.gameSave?.identifier ?? expectedGame.identifier)
                let sanitizedFilename = filename.sanitizedFilePath()
                
                let destinationURL = backupsDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension(saveFileExtension)
                try FileManager.default.copyItem(at: expectedGame.gameSaveURL, to: destinationURL, shouldReplace: true)
                
                Logger.database.notice("Backed up expected save file \(expectedGame.gameSaveURL.lastPathComponent, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
                
                let rtcFileURL = expectedGame.gameSaveURL.deletingPathExtension().appendingPathExtension("rtc")
                if FileManager.default.fileExists(atPath: rtcFileURL.path)
                {
                    let destinationURL = backupsDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension("rtc")
                    try FileManager.default.copyItem(at: rtcFileURL, to: destinationURL, shouldReplace: true)
                    
                    Logger.database.notice("Backed up expected RTC save file \(rtcFileURL.lastPathComponent, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
                }
            }
        }
        else
        {
            @discardableResult
            func backUp(_ saveFileURL: URL) throws -> Bool
            {
                guard FileManager.default.fileExists(atPath: saveFileURL.path) else { return false }
                
                // Filename = expectedGame.name? + gameSave.identifier
                
                let filename: String
                if let expectedGame
                {
                    filename = expectedGame.name + "_" + gameSave.identifier
                }
                else
                {
                    filename = gameSave.identifier
                }
                
                let sanitizedFilename = filename.sanitizedFilePath()
                
                let destinationURL = backupsDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension(saveFileURL.pathExtension)
                try FileManager.default.copyItem(at: saveFileURL, to: destinationURL, shouldReplace: true)
                
                Logger.database.notice("Backed up discovered save file \(saveFileURL.lastPathComponent, privacy: .public) to \(destinationURL.lastPathComponent, privacy: .public)")
                
                return true
            }
            
            // GameSave is _not_ linked to a Game, so instead we iterate through all save files on disk to find match.
            let savURL = self.gameSavesDirectory.appendingPathComponent(gameSave.identifier).appendingPathExtension("sav")
            let srmURL = self.gameSavesDirectory.appendingPathComponent(gameSave.identifier).appendingPathExtension("srm")
            let dsvURL = self.gameSavesDirectory.appendingPathComponent(gameSave.identifier).appendingPathExtension("dsv")
            
            let saveFileURLs = [savURL, srmURL, dsvURL]
            for saveFileURL in saveFileURLs
            {
                if try backUp(saveFileURL)
                {
                    break
                }
            }
            
            // ALWAYS attempt to back up RTC file.
            let rtcURL = self.gameSavesDirectory.appendingPathComponent(gameSave.identifier).appendingPathExtension("rtc")
            try backUp(rtcURL)
        }
    }
    
    func showReviewViewController()
    {
        Logger.database.info("Finished repairing Games and GameSaves, reviewing recent SaveStates...")
        
        let viewController = ReviewSaveStatesViewController()
        viewController.filter = .sinceLastBeta
        viewController.completionHandler = { [weak self] in
            self?.finish()
        }
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    func finish()
    {
        Logger.database.info("Finished repairing database!")
        
        DispatchQueue.global(qos: .userInitiated).async {
            if #available(iOS 15, *)
            {
                do
                {
                    let store = try OSLogStore(scope: .currentProcessIdentifier)
                    
                    // All logs since the app launched.
                    let position = store.position(timeIntervalSinceLatestBoot: 0)
                    
                    let entries = try store.getEntries(at: position)
                        .compactMap { $0 as? OSLogEntryLog }
                        .filter { $0.subsystem == Logger.deltaSubsystem || $0.subsystem == Logger.harmonySubsystem }
                        .map { "[\($0.date.formatted())] [\($0.level.localizedName)] \($0.composedMessage)" }
                                    
                    let outputURL = self.backupsDirectory.appendingPathComponent("repair.log")
                    try FileManager.default.createDirectory(at: self.backupsDirectory, withIntermediateDirectories: true)
                    
                    let outputText = entries.joined(separator: "\n")
                    try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
                }
                catch
                {
                    print("Failed to export Harmony logs.", error)
                }
            }
            
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: NSLocalizedString("Database Repaired", comment: ""),
                                                        message: NSLocalizedString("Some save files may still be corrupted and require you to restore an older version from the Delta Sync settings.\n\nA text file listing all affected games has been saved to “On My Device/Delta/Backups/conflicts.txt” in the Files app, alongside backups of any conflicted save files.", comment: ""),
                                                        preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: UIAlertAction.ok.title, style: UIAlertAction.ok.style) { _ in
                    self.completionHandler?()
                })
                self.present(alertController, animated: true)
            }
        }
    }
}
