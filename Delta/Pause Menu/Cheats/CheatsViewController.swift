//
//  CheatsViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import Roxas

protocol CheatsViewControllerDelegate: class
{
    func cheatsViewControllerActiveGame(saveStatesViewController: CheatsViewController) -> Game
}

class CheatsViewController: UITableViewController
{
    weak var delegate: CheatsViewControllerDelegate! {
        didSet {
            self.updateFetchedResultsController()
        }
    }
    
    private var backgroundView: RSTBackgroundView!
    
    private var fetchedResultsController: NSFetchedResultsController!
}

extension CheatsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Cheats", comment: "")
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.hidden = false
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Cheats", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.whiteColor()
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can add a new cheat by pressing the + button in the top right.", comment: "")
        self.backgroundView.detailTextLabel.textColor = UIColor.whiteColor()
        self.tableView.backgroundView = self.backgroundView
    }
    
    override func viewWillAppear(animated: Bool)
    {
        self.fetchedResultsController.performFetchIfNeeded()
        
        self.updateBackgroundView()
        
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

private extension CheatsViewController
{
    //MARK: - Update -
    
    func updateFetchedResultsController()
    {
        let game = self.delegate.cheatsViewControllerActiveGame(self)
        
        let fetchRequest = Cheat.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", Cheat.Attributes.game.rawValue, game)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Cheat.Attributes.name.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        self.fetchedResultsController.delegate = self
    }
    
    func updateBackgroundView()
    {
        if let fetchedObjects = self.fetchedResultsController.fetchedObjects where fetchedObjects.count > 0
        {
            self.tableView.separatorStyle = .SingleLine
            self.backgroundView.hidden = true
        }
        else
        {
            self.tableView.separatorStyle = .None
            self.backgroundView.hidden = false
        }
    }
}

extension CheatsViewController
{
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        // #warning Incomplete implementation, return the number of sections
        return 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }
}

//MARK: - <NSFetchedResultsControllerDelegate> -
extension CheatsViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.tableView.reloadData()
        self.updateBackgroundView()
    }
}
