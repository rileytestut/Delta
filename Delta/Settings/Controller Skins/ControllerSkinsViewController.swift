//
//  ControllerSkinsViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import Roxas

protocol ControllerSkinsViewControllerDelegate: AnyObject
{
    func controllerSkinsViewController(_ controllerSkinsViewController: ControllerSkinsViewController, didChooseControllerSkin controllerSkin: ControllerSkin)
    func controllerSkinsViewControllerDidResetControllerSkin(_ controllerSkinsViewController: ControllerSkinsViewController)
}

class ControllerSkinsViewController: UITableViewController
{
    weak var delegate: ControllerSkinsViewControllerDelegate?
    
    var system: System! {
        didSet {
            self.updateDataSource()
        }
    }
    
    var traits: DeltaCore.ControllerSkin.Traits! {
        didSet {
            self.updateDataSource()
        }
    }
    
    var isResetButtonVisible: Bool = true
    
    private let dataSource: RSTFetchedResultsTableViewPrefetchingDataSource<ControllerSkin, UIImage>
    
    required init?(coder aDecoder: NSCoder)
    {
        self.dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<ControllerSkin, UIImage>(fetchedResultsController: NSFetchedResultsController())
        
        super.init(coder: aDecoder)
        
        self.prepareDataSource()
    }
}

extension ControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        
        if !self.isResetButtonVisible
        {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

private extension ControllerSkinsViewController
{
    //MARK: - Update
    func prepareDataSource()
    {
        self.dataSource.proxy = self
        self.dataSource.cellConfigurationHandler = { (cell, item, indexPath) in
            let cell = cell as! ControllerSkinTableViewCell
            
            cell.controllerSkinImageView.image = nil
            cell.activityIndicatorView.startAnimating()
        }
        
        self.dataSource.prefetchHandler = { [unowned self] (controllerSkin, indexPath, completionHandler) in
            let imageOperation = LoadControllerSkinImageOperation(controllerSkin: controllerSkin, traits: self.traits, size: UIScreen.main.defaultControllerSkinSize)
            imageOperation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
            
            return imageOperation
        }
        
        self.dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image, let cell = cell as? ControllerSkinTableViewCell else { return }
            
            cell.controllerSkinImageView.image = image
            cell.activityIndicatorView.stopAnimating()
        }
    }
    
    func updateDataSource()
    {
        guard let system = self.system, let traits = self.traits else { return }
        
        let configuration = ControllerSkinConfigurations(traits: traits)
        
        let fetchRequest: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
        
        if traits.device == .iphone && traits.displayType == .edgeToEdge
        {
            let fallbackConfiguration: ControllerSkinConfigurations = (traits.orientation == .landscape) ? .standardLandscape : .standardPortrait
            
            // Allow selecting skins that only support standard display types as well.
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND ((%K & %d) != 0 OR (%K & %d) != 0)",
                                                 #keyPath(ControllerSkin.gameType), system.gameType.rawValue,
                                                 #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue,
                                                 #keyPath(ControllerSkin.supportedConfigurations), fallbackConfiguration.rawValue)
        }
        else
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND (%K & %d) != 0",
                                                 #keyPath(ControllerSkin.gameType), system.gameType.rawValue,
                                                 #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(ControllerSkin.isStandard), ascending: false), NSSortDescriptor(key: #keyPath(ControllerSkin.name), ascending: true)]
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(ControllerSkin.name), cacheName: nil)
    }
    
    @IBAction func resetControllerSkin(_ sender: UIBarButtonItem)
    {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(.cancel)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Reset Controller Skin to Default", comment: ""), style: .destructive, handler: { (action) in
            self.delegate?.controllerSkinsViewControllerDidResetControllerSkin(self)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
}

extension ControllerSkinsViewController
{
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let controllerSkin = self.dataSource.item(at: IndexPath(row: 0, section: section))
        return controllerSkin.name
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        return !controllerSkin.isStandard
    }
        
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            let controllerSkin = context.object(with: controllerSkin.objectID) as! ControllerSkin
            context.delete(controllerSkin)
            
            do
            {
                try context.save()
            }
            catch
            {
                print("Error deleting controller skin:", error)
            }
        }
    }
}

extension ControllerSkinsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        self.delegate?.controllerSkinsViewController(self, didChooseControllerSkin: controllerSkin)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        
        guard let traits = controllerSkin.supportedTraits(for: self.traits), let size = controllerSkin.aspectRatio(for: traits) else { return 150 }
                
        let scale = (self.view.bounds.width / size.width)
        
        let height = min(size.height * scale, self.view.bounds.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom - 30)
        
        return height
    }
}
