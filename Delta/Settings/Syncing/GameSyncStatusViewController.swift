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
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        
        return dateFormatter
    }()
    
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
    }
}

private extension GameSyncStatusViewController
{
    private func makeDataSource() -> RSTCompositeTableViewDataSource<NSManagedObject>
    {
        func configure(_ cell: UITableViewCell, recordedObject: NSManagedObject)
        {
            if let record = self.recordsByObjectURI[recordedObject.objectID.uriRepresentation()], record.isConflicted
            {
                cell.textLabel?.textColor = .red
            }
            else
            {
                cell.textLabel?.textColor = .darkText
            }
        }
        
        let gameDataSource = RSTArrayTableViewDataSource<Game>(items: [self.game])
        gameDataSource.cellConfigurationHandler = { (cell, game, indexPath) in
            cell.textLabel?.text = game.name
            
            configure(cell, recordedObject: game)
        }
        
        let saveStatesFetchRequest = SaveState.fetchRequest() as NSFetchRequest<SaveState>
        saveStatesFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(SaveState.game), self.game)
        saveStatesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.creationDate, ascending: true)]
        
        let saveStatesDataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: saveStatesFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        saveStatesDataSource.cellConfigurationHandler = { (cell, saveState, indexPath) in
            if let name = saveState.name
            {
                cell.textLabel?.text = name
            }
            else
            {
                cell.textLabel?.text = self.dateFormatter.string(from: saveState.modifiedDate)
            }
            
            configure(cell, recordedObject: saveState)
        }
        
        let cheatsFetchRequest = Cheat.fetchRequest() as NSFetchRequest<Cheat>
        cheatsFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Cheat.game), self.game)
        cheatsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Cheat.name, ascending: true)]
        
        let cheatsDataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: cheatsFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        cheatsDataSource.cellConfigurationHandler = { (cell, cheat, indexPath) in
            cell.textLabel?.text = cheat.name
            
            configure(cell, recordedObject: cheat)
        }
        
        let dataSources = [gameDataSource, saveStatesDataSource, cheatsDataSource] as! [RSTArrayTableViewDataSource<NSManagedObject>]
        
        let dataSource = RSTCompositeTableViewDataSource(dataSources: dataSources)
        dataSource.proxy = self
        return dataSource
    }
    
    func fetchRecords()
    {
        var recordsByObjectURI = [URL: Record<NSManagedObject>]()
        
        do
        {
            let recordedObjects = ([self.game!] + Array(self.game.saveStates) + Array(self.game.cheats)) as! [SyncableManagedObject]
            let records = try SyncManager.shared.recordController.fetchRecords(for: recordedObjects)
            
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
        case .game: return NSLocalizedString("Game", comment: "")
        case .saveStates: return NSLocalizedString("Save States", comment: "")
        case .cheats: return NSLocalizedString("Cheats", comment: "")
        }
    }
}
