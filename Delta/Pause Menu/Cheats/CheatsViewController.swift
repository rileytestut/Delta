//
//  CheatsViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import SwiftUI

import DeltaCore

import Roxas

protocol CheatsViewControllerDelegate: class
{
    func cheatsViewController(_ cheatsViewController: CheatsViewController, activateCheat cheat: Cheat)
    func cheatsViewController(_ cheatsViewController: CheatsViewController, deactivateCheat cheat: Cheat)
}

class CheatsViewController: UITableViewController
{
    var game: Game! {
        didSet {
            self.updateDataSource()
        }
    }
    
    weak var delegate: CheatsViewControllerDelegate?
    
    private let dataSource = RSTFetchedResultsTableViewDataSource<Cheat>(fetchedResultsController: NSFetchedResultsController())
}

extension CheatsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Cheats", comment: "")
        
        let vibrancyEffect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark))
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        
        let placeholderView = RSTPlaceholderView(frame: CGRect(x: 0, y: 0, width: vibrancyView.bounds.width, height: vibrancyView.bounds.height))
        placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placeholderView.textLabel.text = NSLocalizedString("No Cheats", comment: "")
        placeholderView.textLabel.textColor = UIColor.white
        placeholderView.detailTextLabel.text = NSLocalizedString("You can add a new cheat by pressing the + button in the top right.", comment: "")
        placeholderView.detailTextLabel.textColor = UIColor.white
        vibrancyView.contentView.addSubview(placeholderView)
        
        self.dataSource.placeholderView = vibrancyView
        self.dataSource.rowAnimation = .automatic
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, item, indexPath) in
            self.configure(cell, for: indexPath)
        }
        self.tableView.dataSource = self.dataSource
        
        self.tableView.separatorEffect = vibrancyEffect
        
        self.registerForPreviewing(with: self, sourceView: self.tableView)
        
        if #available(iOS 14, *)
        {
            let addCheatMenu = UIMenu(children: [
                UIAction(title: NSLocalizedString("New Cheat Code", comment: ""), image: UIImage(systemName: "square.and.pencil")) { [weak self] _ in
                    self?.addCheat()
                },
                
                UIAction(title: NSLocalizedString("Search CheatBase", comment: ""), image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
                    self?.searchCheatBase()
                },
            ])
            
            self.navigationItem.rightBarButtonItem?.target = nil
            self.navigationItem.rightBarButtonItem?.action = nil
            
            self.navigationItem.rightBarButtonItem?.menu = addCheatMenu
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

//MARK: - Navigation -
private extension CheatsViewController
{
    @IBAction func unwindFromEditCheatViewController(_ segue: UIStoryboardSegue)
    {
        
    }
}

//MARK: - Update -
private extension CheatsViewController
{
    func updateDataSource()
    {
        let fetchRequest: NSFetchRequest<Cheat> = Cheat.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Cheat.game), self.game)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Cheat.name), ascending: true)]
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
    }
}

//MARK: - Managing Cheats -
/// Managing Cheats
private extension CheatsViewController
{
    @IBAction func addCheat()
    {
        let editCheatViewController = self.makeEditCheatViewController(cheat: nil)
        editCheatViewController.presentWithPresentingViewController(self)
    }
    
    @available(iOS 14, *)
    func searchCheatBase()
    {
        var rootView = CheatBaseView(game: self.game)
        rootView.cancellationHandler = { [weak self] in
            self?.presentedViewController?.dismiss(animated: true)
        }
        
        rootView.selectionHandler = { [weak self] cheatMetadata in
            self?.saveCheatMetadata(cheatMetadata)
            self?.presentedViewController?.dismiss(animated: true)
        }
        
        let hostingController = UIHostingController(rootView: rootView)
        self.present(hostingController, animated: true, completion: nil)
    }
    
    func saveCheatMetadata(_ cheatMetadata: CheatMetadata)
    {
        DatabaseManager.shared.performBackgroundTask { context in
            do
            {
                guard let cheatType = cheatMetadata.device.cheatType, let cheatFormat = cheatMetadata.device.cheatFormat else { throw CheatValidator.Error.unknownCheatType }
                
                let cheat = Cheat(context: context)
                cheat.name = cheatMetadata.name
                cheat.type = cheatType
                cheat.isEnabled = true
                
                let sanitizedCode = cheatMetadata.code.components(separatedBy: .whitespacesAndNewlines).joined()
                let formattedCode = sanitizedCode.formatted(with: cheatFormat)
                cheat.code = formattedCode
                
                let game = context.object(with: self.game.objectID) as! Game
                cheat.game = game
                
                let validator = CheatValidator(format: cheatFormat, managedObjectContext: context)
                try validator.validate(cheat)
                
                self.delegate?.cheatsViewController(self, activateCheat: cheat)
                
                try context.save()
            }
            catch
            {
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Add Cheat", comment: ""), error: error)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    func deleteCheat(_ cheat: Cheat)
    {
        self.delegate?.cheatsViewController(self, deactivateCheat: cheat)
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            let temporaryCheat = context.object(with: cheat.objectID)
            context.delete(temporaryCheat)
            context.saveWithErrorLogging()
        }
    }
}

//MARK: - Convenience -
/// Convenience
private extension CheatsViewController
{
    func configure(_ cell: UITableViewCell, for indexPath: IndexPath)
    {
        let cheat = self.dataSource.item(at: indexPath)
        cell.textLabel?.text = cheat.name
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: cell.textLabel!.font.pointSize)
        cell.textLabel?.textColor = UIColor.white
        cell.accessoryType = cheat.isEnabled ? .checkmark : .none
    }
    
    func makeEditCheatViewController(cheat: Cheat?) -> EditCheatViewController
    {        
        let editCheatViewController = self.storyboard!.instantiateViewController(withIdentifier: "editCheatViewController") as! EditCheatViewController
        editCheatViewController.delegate = self
        editCheatViewController.cheat = cheat
        editCheatViewController.game = self.game
        
        return editCheatViewController
    }
}

extension CheatsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cheat = self.dataSource.item(at: indexPath)
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            let temporaryCheat = backgroundContext.object(with: cheat.objectID) as! Cheat
            temporaryCheat.isEnabled = !temporaryCheat.isEnabled
            
            if temporaryCheat.isEnabled
            {
                self.delegate?.cheatsViewController(self, activateCheat: temporaryCheat)
            }
            else
            {
                self.delegate?.cheatsViewController(self, deactivateCheat: temporaryCheat)
            }
            
            backgroundContext.saveWithErrorLogging()
        }
        
        self.tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let cheat = self.dataSource.item(at: indexPath)
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { (action, indexPath) in
            self.deleteCheat(cheat)
        }
        
        let editAction = UITableViewRowAction(style: .normal, title: NSLocalizedString("Edit", comment: "")) { (action, indexPath) in
            let editCheatViewController = self.makeEditCheatViewController(cheat: cheat)
            editCheatViewController.presentWithPresentingViewController(self)
        }
        
        return [deleteAction, editAction]
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        // This method intentionally left blank because someone decided it was a Good Idea™ to require this method be implemented to use UITableViewRowActions
    }
}

//MARK: - <UIViewControllerPreviewingDelegate> -
extension CheatsViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else { return nil }
        
        let frame = self.tableView.rectForRow(at: indexPath)
        previewingContext.sourceRect = frame
        
        let cheat = self.dataSource.item(at: indexPath)
        
        let editCheatViewController = self.makeEditCheatViewController(cheat: cheat)
        editCheatViewController.isPreviewing = true
        return editCheatViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        let editCheatViewController = viewControllerToCommit as! EditCheatViewController
        editCheatViewController.isPreviewing = false
        editCheatViewController.presentWithPresentingViewController(self)
    }
}

//MARK: - <EditCheatViewControllerDelegate> -
extension CheatsViewController: EditCheatViewControllerDelegate
{
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, activateCheat cheat: Cheat, previousCheat: Cheat?)
    {
        self.delegate?.cheatsViewController(self, activateCheat: cheat)
        
        if let previousCheat = previousCheat
        {
            let code = cheat.code
            
            previousCheat.managedObjectContext?.performAndWait({
                
                guard previousCheat.code != code else { return }
                
                self.delegate?.cheatsViewController(self, deactivateCheat: previousCheat)
            })
        }
    }
    
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, deactivateCheat cheat: Cheat)
    {
        self.delegate?.cheatsViewController(self, deactivateCheat: cheat)
    }
}
