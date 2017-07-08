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

class ControllerSkinsViewController: UITableViewController
{
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
    
    fileprivate let dataSource: RSTFetchedResultsTableViewPrefetchingDataSource<ControllerSkin, UIImage>
    
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
            
            // Ensure initially visible cells have loaded their image before they appear to prevent potential flickering from placeholder to thumbnail
            if self.isAppearing
            {
                imageOperation.start()
                imageOperation.waitUntilFinished()
                return nil
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
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND (%K & %d) == %d", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue, configuration.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(ControllerSkin.isStandard), ascending: false), NSSortDescriptor(key: #keyPath(ControllerSkin.name), ascending: true)]
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(ControllerSkin.name), cacheName: nil)
    }
}

extension ControllerSkinsViewController
{
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let controllerSkin = self.dataSource.item(at: IndexPath(row: 0, section: section))
        return controllerSkin.name
    }
}

extension ControllerSkinsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        Settings.setPreferredControllerSkin(controllerSkin, for: self.system, traits: self.traits)
        
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        
        guard let size = controllerSkin.aspectRatio(for: self.traits) else { return 150 }
        
        let scale = (self.view.bounds.width / size.width)
        
        let height = size.height * scale
        
        return height
    }
}
