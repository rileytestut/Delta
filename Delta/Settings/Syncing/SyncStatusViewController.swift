//
//  SyncStatusViewController.swift
//  Delta
//
//  Created by Riley Testut on 11/15/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class SyncStatusViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    private var gameConflictsCount: [URL: Int]?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.definesPresentationContext = true
        
        self.tableView.dataSource = self.dataSource
        
        let fetchedDataSource = self.dataSource.dataSources.last
        self.navigationItem.searchController = fetchedDataSource?.searchController
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchConflictedRecords()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showGame":
            guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell) else { return }
            
            let game = self.dataSource.item(at: indexPath)
            
            let gameSyncStatusViewController = segue.destination as! GameSyncStatusViewController
            gameSyncStatusViewController.game = game
            
        case "showPreviousSyncResults":
            let syncResultViewController = segue.destination as! SyncResultViewController
            syncResultViewController.result = SyncManager.shared.previousSyncResult
            
        default: break
        }
    }
}

private extension SyncStatusViewController
{
    func makeDataSource() -> RSTCompositeTableViewDataSource<Game>
    {
        let fetchRequest = Game.fetchRequest() as NSFetchRequest<Game>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.gameCollection?.index, ascending: true), NSSortDescriptor(key: #keyPath(Game.name), ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(Game.gameCollection.name), cacheName: nil)
        
        let fetchedDataSource = RSTFetchedResultsTableViewDataSource(fetchedResultsController: fetchedResultsController)
        fetchedDataSource.searchController.searchableKeyPaths = [#keyPath(Game.name)]
        fetchedDataSource.cellConfigurationHandler = { [weak self] (cell, game, indexPath) in
            let cell = cell as! BadgedTableViewCell
            cell.textLabel?.text = game.name
            cell.textLabel?.numberOfLines = 0
            
            if let gameConflictsCount = self?.gameConflictsCount
            {
                if let count = gameConflictsCount[game.objectID.uriRepresentation()], count > 0
                {
                    cell.badgeLabel.text = String(describing: count)
                    cell.badgeLabel.isHidden = false
                }
                else
                {
                    cell.badgeLabel.isHidden = true
                }
                
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = nil
            }
            else
            {
                let activityIndicatorView = UIActivityIndicatorView(style: .gray)
                activityIndicatorView.startAnimating()
                
                cell.accessoryType = .none
                cell.accessoryView = activityIndicatorView
                
                cell.badgeLabel.isHidden = true
            }
        }
        
        let dynamicDataSource = RSTDynamicTableViewDataSource<Game>()
        dynamicDataSource.numberOfSectionsHandler = { (SyncManager.shared.previousSyncResult != nil) ? 1 : 0 }
        dynamicDataSource.numberOfItemsHandler = { _ in 1 }
        dynamicDataSource.cellIdentifierHandler = { _ in "PreviousSyncCell" }
        dynamicDataSource.cellConfigurationHandler = { (cell, _, indexPath) in }
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("No Games", comment: "")
        placeholderView.detailTextLabel.text = NSLocalizedString("Check back here after adding games to Delta to see their sync status.", comment: "")
        
        let dataSource = RSTCompositeTableViewDataSource(dataSources: [dynamicDataSource, fetchedDataSource])
        dataSource.proxy = self
        dataSource.placeholderView = placeholderView
        return dataSource
    }
    
    func fetchConflictedRecords()
    {
        guard let recordController = SyncManager.shared.recordController else { return }
        
        DispatchQueue.global().async {
            do
            {
                var gameConflictsCount = [URL: Int]()
                
                let records = try recordController.fetchConflictedRecords()
                
                for record in records
                {
                    guard let recordedObject = record.recordedObject else { continue }
                    recordedObject.managedObjectContext?.performAndWait {
                        let conflictedGame: Game?
                        
                        switch recordedObject
                        {
                        case let game as Game: conflictedGame = game
                        case let saveState as SaveState: conflictedGame = saveState.game
                        case let cheat as Cheat: conflictedGame = cheat.game
                        case let gameSave as GameSave: conflictedGame = gameSave.game
                        default: conflictedGame = nil
                        }
                        
                        guard let game = conflictedGame else { return }
                        
                        gameConflictsCount[game.objectID.uriRepresentation(), default: 0] += 1
                    }
                }
                
                self.gameConflictsCount = gameConflictsCount
            }
            catch
            {
                print(error)
                
                self.gameConflictsCount = [:]
                
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: NSLocalizedString("Failed to Get Sync Status", comment: ""),
                                                            message: error.localizedDescription,
                                                            preferredStyle: .alert)
                    alertController.addAction(.ok)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}

extension SyncStatusViewController
{
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        var section = section
        
        if SyncManager.shared.previousSyncResult != nil
        {
            guard section > 0 else { return nil }
            
            section -= 1
        }
        
        let dataSource = self.dataSource.dataSources[1] as! RSTFetchedResultsTableViewDataSource
        
        let sectionInfo = dataSource.fetchedResultsController.sections?[section]
        return sectionInfo?.name
    }
}
