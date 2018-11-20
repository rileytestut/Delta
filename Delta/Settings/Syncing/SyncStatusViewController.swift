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
        
        self.tableView.dataSource = self.dataSource
        self.navigationItem.searchController = self.dataSource.searchController
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchConflictedRecords()
    }
}

private extension SyncStatusViewController
{
    func makeDataSource() -> RSTFetchedResultsTableViewDataSource<Game>
    {
        let fetchRequest = Game.fetchRequest() as NSFetchRequest<Game>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.gameCollection?.index, ascending: true), NSSortDescriptor(key: #keyPath(Game.name), ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(Game.gameCollection.name), cacheName: nil)
        
        let dataSource = RSTFetchedResultsTableViewDataSource(fetchedResultsController: fetchedResultsController)
        dataSource.proxy = self
        dataSource.searchController.searchableKeyPaths = [#keyPath(Game.name)]
        dataSource.cellConfigurationHandler = { (cell, game, indexPath) in
            let cell = cell as! BadgedTableViewCell
            cell.textLabel?.text = game.name
            cell.textLabel?.numberOfLines = 0
            
            if let gameConflictsCount = self.gameConflictsCount
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
        
        return dataSource
    }
    
    func fetchConflictedRecords()
    {
        DispatchQueue.global().async {
            do
            {
                var gameConflictsCount = [URL: Int]()
                
                let records = try SyncManager.shared.recordController.fetchConflictedRecords()
                
                for record in records
                {
                    guard let recordedObject = record.recordedObject else { continue }
                    
                    let conflictedGame: Game?
                    
                    switch recordedObject
                    {
                    case let game as Game: conflictedGame = game
                    case let saveState as SaveState: conflictedGame = saveState.game
                    case let cheat as Cheat: conflictedGame = cheat.game
                    default: conflictedGame = nil
                    }
                    
                    guard let game = conflictedGame else { continue }
                    
                    gameConflictsCount[game.objectID.uriRepresentation(), default: 0] += 1
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
        let section = self.dataSource.fetchedResultsController.sections?[section]
        return section?.name
    }
}
