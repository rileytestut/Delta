//
//  GameSyncStatusViewController.swift
//  Delta
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

import Roxas
import Harmony

extension GameSyncStatusViewController
{
    private enum Section: Int, CaseIterable
    {
        case game
        case saveStates
        case cheats
    }
}

class GameSyncStatusViewController: UITableViewController
{
    var game: Game!
    
    private lazy var dataSource = self.makeDataSource()
    
    private var recordsByObjectURI = [URL: Record<NSManagedObject>]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = self.game.name
        
        self.tableView.dataSource = self.dataSource
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.fetchRecords()
        
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "showRecord" else { return }
        
        guard let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell) else { return }
        
        let recordedObject = self.dataSource.item(at: indexPath) as! Syncable
        
        do
        {
            let records = try SyncManager.shared.recordController?.fetchRecords(for: [recordedObject]) ?? []
            
            let recordSyncStatusViewController = segue.destination as! RecordSyncStatusViewController
            recordSyncStatusViewController.record = records.first
        }
        catch
        {
            print(error)
        }
    }
}

private extension GameSyncStatusViewController
{
    private func makeDataSource() -> RSTCompositeTableViewDataSource<NSManagedObject>
    {
        // Use closure instead of local function to allow us to capture `self` weakly.
        let configure = { [weak self] (cell: UITableViewCell, recordedObject: NSManagedObject) in
            if let record = self?.recordsByObjectURI[recordedObject.objectID.uriRepresentation()], record.isConflicted
            {
                if #available(iOS 13.0, *) {
                    cell.textLabel?.textColor = .systemRed
                } else {
                    cell.textLabel?.textColor = .red
                }
            }
            else
            {
                if #available(iOS 13.0, *) {
                    cell.textLabel?.textColor = .label
                } else {
                    cell.textLabel?.textColor = .darkText
                }
            }
        }
        
        let gameDataSource = RSTArrayTableViewDataSource<NSManagedObject>(items: [self.game, self.game.gameSave].compactMap { $0 })
        gameDataSource.cellConfigurationHandler = { (cell, item, indexPath) in
            if item is Game
            {
                cell.textLabel?.text = NSLocalizedString("Game", comment: "")
            }
            else
            {
                cell.textLabel?.text = NSLocalizedString("Game Save", comment: "")
            }
            
            configure(cell, item)
        }
        
        let saveStatesFetchRequest = SaveState.fetchRequest() as NSFetchRequest<SaveState>
        saveStatesFetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K != %@ AND %K != %@",
                                                       #keyPath(SaveState.game), self.game,
                                                       #keyPath(SaveState.type), NSNumber(value: SaveStateType.auto.rawValue),
                                                       #keyPath(SaveState.type), NSNumber(value: SaveStateType.quick.rawValue))
        saveStatesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.creationDate, ascending: true)]
        
        let saveStatesDataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: saveStatesFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        saveStatesDataSource.cellConfigurationHandler = { (cell, saveState, indexPath) in
            cell.textLabel?.text = saveState.localizedName
            configure(cell, saveState)
        }
        
        let cheatsFetchRequest = Cheat.fetchRequest() as NSFetchRequest<Cheat>
        cheatsFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Cheat.game), self.game)
        cheatsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Cheat.name, ascending: true)]
        
        let cheatsDataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: cheatsFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        cheatsDataSource.cellConfigurationHandler = { (cell, cheat, indexPath) in
            cell.textLabel?.text = cheat.name
            
            configure(cell, cheat)
        }
        
        let dataSources = [gameDataSource, saveStatesDataSource, cheatsDataSource] as! [RSTArrayTableViewDataSource<NSManagedObject>]
        
        let dataSource = RSTCompositeTableViewDataSource(dataSources: dataSources)
        dataSource.proxy = self
        return dataSource
    }
    
    func fetchRecords()
    {
        guard let recordController = SyncManager.shared.recordController else { return }
        
        var recordsByObjectURI = [URL: Record<NSManagedObject>]()
        
        do
        {
            let recordedObjects = ([self.game, self.game.gameSave].compactMap { $0 } + Array(self.game.saveStates) + Array(self.game.cheats)) as! [Syncable]
            let records = try recordController.fetchRecords(for: recordedObjects)
            
            for record in records
            {
                guard let recordedObject = record.recordedObject else { continue }
                
                recordsByObjectURI[recordedObject.objectID.uriRepresentation()] = record
            }
        }
        catch
        {
            print(error)
        }
        
        self.recordsByObjectURI = recordsByObjectURI
    }
}

extension GameSyncStatusViewController
{
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard self.dataSource.tableView(self.tableView, numberOfRowsInSection: section) > 0 else { return nil }
        
        switch Section.allCases[section]
        {
        case .game: return nil
        case .saveStates: return NSLocalizedString("Save States", comment: "")
        case .cheats: return NSLocalizedString("Cheats", comment: "")
        }
    }
}
