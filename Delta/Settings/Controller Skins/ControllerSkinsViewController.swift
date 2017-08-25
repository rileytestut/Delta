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

extension ControllerSkinsViewController
{
    enum Section: Int
    {
        case standard
        case custom
    }
}

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
    
    fileprivate let dataSource = RSTFetchedResultsTableViewDataSource<ControllerSkin>(fetchedResultsController: NSFetchedResultsController())
    
    fileprivate let imageOperationQueue = RSTOperationQueue()
    
    fileprivate let imageCache = NSCache<ControllerSkinImageCacheKey, UIImage>()
}

extension ControllerSkinsViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.dataSource.proxy = self
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, item, indexPath) in
            self.configure(cell as! ControllerSkinTableViewCell, for: indexPath)
        }
        self.tableView.dataSource = self.dataSource
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
    func updateDataSource()
    {
        guard let system = self.system, let traits = self.traits else { return }
        
        let configuration = ControllerSkinConfigurations(traits: traits)
        
        let fetchRequest: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND (%K & %d) == %d", #keyPath(ControllerSkin.gameType), system.gameType.rawValue, #keyPath(ControllerSkin.supportedConfigurations), configuration.rawValue, configuration.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(ControllerSkin.isStandard), ascending: false), NSSortDescriptor(key: #keyPath(ControllerSkin.name), ascending: true)]
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(ControllerSkin.name), cacheName: nil)
    }
    
    //MARK: - Configure Cells
    func configure(_ cell: ControllerSkinTableViewCell, for indexPath: IndexPath)
    {
        let controllerSkin = self.dataSource.item(at: indexPath)
        
        cell.controllerSkinImageView.image = nil
        cell.activityIndicatorView.startAnimating()
        
        let size = UIScreen.main.defaultControllerSkinSize
        
        let imageOperation = LoadControllerSkinImageOperation(controllerSkin: controllerSkin, traits: self.traits, size: size)
        imageOperation.resultsCache = self.imageCache
        imageOperation.resultHandler = { (image, error) in
            
            guard let image = image else { return }
            
            if !imageOperation.isImmediate
            {
                UIView.transition(with: cell.controllerSkinImageView, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    cell.controllerSkinImageView.image = image
                }, completion: nil)
            }
            else
            {
                cell.controllerSkinImageView.image = image
            }
            
            cell.activityIndicatorView.stopAnimating()
        }
        
        // Ensure initially visible cells have loaded their image before they appear to prevent potential flickering from placeholder to thumbnail
        if self.isAppearing
        {
            imageOperation.isImmediate = true
        }
        
        self.imageOperationQueue.addOperation(imageOperation, forKey: indexPath as NSCopying)
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

extension ControllerSkinsViewController: UITableViewDataSourcePrefetching
{
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths
        {
            let controllerSkin = self.dataSource.item(at: indexPath)
            
            let size = UIScreen.main.defaultControllerSkinSize
            
            let imageOperation = LoadControllerSkinImageOperation(controllerSkin: controllerSkin, traits: self.traits, size: size)
            imageOperation.resultsCache = self.imageCache
            
            self.imageOperationQueue.addOperation(imageOperation, forKey: indexPath as NSCopying)
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath])
    {
        for indexPath in indexPaths
        {
            let operation = self.imageOperationQueue[indexPath as NSCopying]
            operation?.cancel()
        }
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
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let operation = self.imageOperationQueue[indexPath as NSCopying]
        operation?.cancel()
    }
}
