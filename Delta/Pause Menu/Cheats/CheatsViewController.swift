//
//  CheatsViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore

import Roxas

protocol CheatsViewControllerDelegate: class
{
    func cheatsViewControllerActiveGame(saveStatesViewController: CheatsViewController) -> Game
    func cheatsViewController(cheatsViewController: CheatsViewController, didActivateCheat cheat: Cheat) throws
    func cheatsViewController(cheatsViewController: CheatsViewController, didDeactivateCheat cheat: Cheat) throws
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

//MARK: - Managing Cheats -
/// Managing Cheats
private extension CheatsViewController
{
    @IBAction func addCheat()
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlock { 
            
            var game = self.delegate.cheatsViewControllerActiveGame(self)
            game = backgroundContext.objectWithID(game.objectID) as! Game
            
            let cheat = Cheat.insertIntoManagedObjectContext(backgroundContext)
            cheat.game = game
            cheat.name = "Unlimited Jumps"
            cheat.code = "3E2C-AF6F"
            cheat.type = .gameGenie
            
            do
            {
                try self.delegate.cheatsViewController(self, didActivateCheat: cheat)
                backgroundContext.saveWithErrorLogging()
            }
            catch EmulatorCore.CheatError.invalid
            {
                dispatch_async(dispatch_get_main_queue()) {
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Invalid Cheat", comment: ""), message: NSLocalizedString("Please make sure you typed the cheat code in correctly and try again.", comment: ""), preferredStyle: .Alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .Default, handler: nil))
                    self.presentViewController(alertController, animated: true, completion: nil)
                    
                }
                
                print("Invalid cheat:", cheat.name, cheat.code)
            }
            catch let error as NSError
            {
                print("Unknown Cheat Error:", error, cheat.name, cheat.code)
            }
            
            
        }
    }
    
    func deleteCheat(cheat: Cheat)
    {
        let _ = try? self.delegate.cheatsViewController(self, didDeactivateCheat: cheat)
        
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlock {
            let temporaryCheat = backgroundContext.objectWithID(cheat.objectID)
            backgroundContext.deleteObject(temporaryCheat)
            backgroundContext.saveWithErrorLogging()
        }
    }
}

//MARK: - Content -
/// Content
private extension CheatsViewController
{
    func configure(cell cell: UITableViewCell, forIndexPath indexPath: NSIndexPath)
    {
        let cheat = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Cheat
        cell.textLabel?.text = cheat.name
        cell.textLabel?.font = UIFont.boldSystemFontOfSize(cell.textLabel!.font.pointSize)
        cell.accessoryType = cheat.enabled ? .Checkmark : .None
    }
}

extension CheatsViewController
{
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        let numberOfSections = self.fetchedResultsController.sections!.count
        return numberOfSections
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = self.fetchedResultsController.sections![section]
        return section.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier(RSTGenericCellIdentifier, forIndexPath: indexPath)
        self.configure(cell: cell, forIndexPath: indexPath)
        return cell
    }
}

extension CheatsViewController
{
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        let cheat = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Cheat
        
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlockAndWait {
            let temporaryCheat = backgroundContext.objectWithID(cheat.objectID) as! Cheat
            temporaryCheat.enabled = !temporaryCheat.enabled
            
            do
            {
                if temporaryCheat.enabled
                {
                    try self.delegate.cheatsViewController(self, didActivateCheat: temporaryCheat)
                }
                else
                {
                    try self.delegate.cheatsViewController(self, didDeactivateCheat: temporaryCheat)
                }
            }
            catch EmulatorCore.CheatError.invalid
            {
                print("Invalid cheat:", cheat.name, cheat.code)
            }
            catch EmulatorCore.CheatError.doesNotExist
            {
                print("Cheat does not exist:", cheat.name, cheat.code)
            }
            catch let error as NSError
            {
                print("Unknown Cheat Error:", error, cheat.name, cheat.code)
            }
            
            backgroundContext.saveWithErrorLogging()
        }
        
        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]?
    {
        let deleteAction = UITableViewRowAction(style: .Destructive, title: NSLocalizedString("Delete", comment: "")) { (action, indexPath) in
            let cheat = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Cheat
            self.deleteCheat(cheat)
        }
        
        let editAction = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: "")) { (action, indexPath) in
            
        }
        
        return [deleteAction, editAction]
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath)
    {
        // This method intentionally left blank because someone decided it was a Good Idea™ to require this method be implemented to use UITableViewRowActions
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
