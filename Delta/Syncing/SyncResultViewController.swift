//
//  SyncResultViewController.swift
//  Delta
//
//  Created by Riley Testut on 11/28/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

import Roxas
import Harmony

@objc(SyncResultTableViewCell)
private class SyncResultTableViewCell: UITableViewCell
{
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var errorLabel: UILabel!
}

extension SyncResultViewController
{
    private enum Group: Hashable
    {
        case game(RecordID)
        case saveState(gameID: RecordID)
        case cheat(gameID: RecordID)
        case controllerSkin
        case gameControllerInputMapping
        case gameCollection
        case other
        
        var sortIndex: Int {
            switch self
            {
            case .game: return 0
            case .saveState: return 1
            case .cheat: return 2
            case .controllerSkin: return 3
            case .gameControllerInputMapping: return 4
            case .gameCollection: return 5
            case .other: return 6
            }
        }
    }
}

class SyncResultViewController: UITableViewController
{
    var result: Result<[Record<NSManagedObject>: Result<Void, RecordError>], SyncError>!
    
    private lazy var dataSource = self.makeDataSource()
    
    private lazy var sortedErrors = self.processResults()
    private lazy var gameNamesByRecordID = self.fetchGameNames()
    
    private init()
    {
        super.init(style: .grouped)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "showRecordStatus" else { return }
        
        guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell) else { return }
        
        guard let recordError = self.dataSource.item(at: indexPath).value as? RecordError else { return }
        
        let recordSyncStatusViewController = segue.destination as! RecordSyncStatusViewController
        recordSyncStatusViewController.record = recordError.record
    }
}

extension SyncResultViewController
{
    class func make(result: Result<[Record<NSManagedObject>: Result<Void, RecordError>], SyncError>) -> UINavigationController
    {
        let storyboard = UIStoryboard(name: "SyncResultsViewController", bundle: nil)
        
        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        
        let syncResultViewController = navigationController.viewControllers[0] as! SyncResultViewController
        syncResultViewController.result = result
        
        return navigationController
    }
}

private extension SyncResultViewController
{
    func makeDataSource() -> RSTCompositeTableViewDataSource<Box<Error>>
    {
        let dataSources = self.sortedErrors.map { (_, errors) -> RSTArrayTableViewDataSource<Box<Error>> in
            let dataSource = RSTArrayTableViewDataSource<Box<Error>>(items: errors.map(Box.init))
            dataSource.cellConfigurationHandler = { (cell, error, indexPath) in
                let cell = cell as! SyncResultTableViewCell
                
                let title: String?
                let errorMessage: String?
                
                switch error.value
                {
                case let error as RecordError:
                    guard let recordType = SyncManager.RecordType(rawValue: error.record.recordID.type) else { return }                    
                    
                    switch recordType
                    {
                    case .game: title = NSLocalizedString("Game", comment: "")
                    case .saveState, .cheat, .controllerSkin, .gameCollection, .gameControllerInputMapping: title = error.record.localizedName ?? recordType.localizedName
                    }
                    
                    switch error
                    {
                    case .filesFailed(_, let errors):
                        var messages = [String]()
                        
                        for error in errors
                        {
                            messages.append(error.localizedDescription)
                        }
                        
                        errorMessage = messages.joined(separator: "\n")
                        
                    default: errorMessage = error.failureReason
                    }
                    
                case let error as HarmonyError:
                    title = error.failureDescription
                    errorMessage = error.failureReason
                    
                case let error:
                    assertionFailure("Only HarmonyErrors should be thrown by syncing logic.")
                    
                    title = nil
                    errorMessage = error.localizedDescription
                }
                
                cell.nameLabel.text = title
                cell.errorLabel.text = errorMessage
            }
            
            return dataSource
        }
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("Sync Successful", comment: "")
        placeholderView.detailTextLabel.text = NSLocalizedString("There were no errors during last sync.", comment: "")
        
        let compositeDataSource = RSTCompositeTableViewDataSource(dataSources: dataSources)
        compositeDataSource.proxy = self
        compositeDataSource.placeholderView = placeholderView
        return compositeDataSource
    }
    
    private func processResults() -> [(group: Group, errors: [Error])]
    {
        var errors = [Error]()
        
        do
        {
            try self.result.verify()
        }
        catch SyncError.partial(let recordResults)
        {
            for (_, result) in recordResults
            {
                guard case .failure(let error) = result else { continue }
                errors.append(error)
            }
        }
        catch SyncError.other(.cancelled)
        {
            // Do nothing
        }
        catch let error as SyncError
        {
            let error = error.underlyingError ?? error
            errors.append(error)
        }
        catch
        {
            assertionFailure("Non-SyncError thrown by sync result.")
            errors.append(error)
        }
        
        var errorsByGroup = [Group: [Error]]()
        
        for error in errors
        {
            let group: Group
            
            switch error
            {
            case let error as RecordError:
                guard let recordType = SyncManager.RecordType(rawValue: error.record.recordID.type) else { continue }
                
                switch recordType
                {
                case .game: group = .game(error.record.recordID)
                case .gameCollection: group = .gameCollection
                case .controllerSkin: group = .controllerSkin
                case .gameControllerInputMapping: group = .gameControllerInputMapping
                    
                case .saveState:
                    guard let gameID = error.record.metadata?[.gameID] else { continue }
                    
                    let recordID = RecordID(type: SyncManager.RecordType.game.rawValue, identifier: gameID)
                    group = .saveState(gameID: recordID)
                    
                case .cheat:
                    guard let gameID = error.record.metadata?[.gameID] else { continue }
                    
                    let recordID = RecordID(type: SyncManager.RecordType.game.rawValue, identifier: gameID)
                    group = .cheat(gameID: recordID)
                }
                
            default: group = .other
            }
            
            errorsByGroup[group, default: []].append(error)
        }
        
        let sortedErrors = errorsByGroup.sorted { (a, b) in
            let groupA = a.key
            let groupB = b.key
            
            // Sort initially by game, then sort by type.
            // This way games and their associated records (such as save states) are visually grouped together.
            switch (groupA, groupB)
            {
            // Game-related records, but different game identifiers, so sort by game identifiers (implicitly grouping related game records together).
            // Using `fallthrough` for these cases seg faults the compiler (as of Swift 4.2.1), so we just duplicate the return expression.
            case (.game(let a), .game(let b)) where a != b: return a.identifier < b.identifier
            case (.game(let a), .saveState(let b)) where a != b: return a.identifier < b.identifier
            case (.game(let a), .cheat(let b)) where a != b: return a.identifier < b.identifier
            case (.saveState(let a), .game(let b)) where a != b: return a.identifier < b.identifier
            case (.saveState(let a), .saveState(let b)) where a != b: return a.identifier < b.identifier
            case (.saveState(let a), .cheat(let b)) where a != b: return a.identifier < b.identifier
            case (.cheat(let a), .game(let b)) where a != b: return a.identifier < b.identifier
            case (.cheat(let a), .saveState(let b)) where a != b: return a.identifier < b.identifier
            case (.cheat(let a), .cheat(let b)) where a != b: return a.identifier < b.identifier
                
            // Otherwise, just return their relative ordering.
            case (.game, _): fallthrough
            case (.saveState, _): fallthrough
            case (.cheat, _): fallthrough
            case (.controllerSkin, _): fallthrough
            case (.gameControllerInputMapping, _): fallthrough
            case (.gameCollection, _): fallthrough
            case (.other, _): return groupA.sortIndex < groupB.sortIndex
            }
        }
        
        return sortedErrors.map { (group: $0.key, errors: $0.value) }
    }
    
    func fetchGameNames() -> [RecordID: String]
    {
        let fetchRequest = Game.fetchRequest() as NSFetchRequest<Game>
        fetchRequest.propertiesToFetch = [#keyPath(Game.name), #keyPath(Game.identifier)]
        
        do
        {
            let games = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
            
            let gameNames = Dictionary(uniqueKeysWithValues: games.map { (RecordID(type: SyncManager.RecordType.game.rawValue, identifier: $0.identifier), $0.name) })
            return gameNames
        }
        catch
        {
            print("Failed to fetch game names.", error)
            
            return [:]
        }
    }
}

private extension SyncResultViewController
{
    @IBAction func dismiss()
    {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension SyncResultViewController
{
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = self.sortedErrors[section]
        
        switch section.group
        {
        case .controllerSkin: return NSLocalizedString("Controller Skins", comment: "")
        case .gameCollection: return NSLocalizedString("Game Collections", comment: "")
        case .gameControllerInputMapping: return NSLocalizedString("Input Mappings", comment: "")
        case .other: return NSLocalizedString("Misc.", comment: "")
            
        case .game:
            guard let error = section.errors.first as? RecordError else { return nil }
            return error.record.localizedName
            
        case .saveState(let gameID):
            guard let error = section.errors.first as? RecordError else { return nil }
            
            if let gameName = self.gameNamesByRecordID[gameID] ?? error.record.metadata?[.gameName]
            {
                return gameName + " - " + NSLocalizedString("Save States", comment: "")
            }
            else
            {
                return NSLocalizedString("Save States", comment: "")
            }
            
        case .cheat(let gameID):
            guard let error = section.errors.first as? RecordError else { return nil }
            
            if let gameName = self.gameNamesByRecordID[gameID] ?? error.record.metadata?[.gameName]
            {
                return gameName + " - " + NSLocalizedString("Cheats", comment: "")
            }
            else
            {
                return NSLocalizedString("Cheats", comment: "")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?
    {
        let section = self.sortedErrors[indexPath.section]
        
        switch section.group
        {
        case .other: return nil
        default: return indexPath
        }
    }
}
