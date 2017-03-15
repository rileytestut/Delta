//
//  GamesDatabaseBrowserViewController.swift
//  Delta
//
//  Created by Riley Testut on 2/6/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class GamesDatabaseBrowserViewController: UITableViewController
{
    var selectionHandler: ((GameMetadata) -> Void)?
    
    fileprivate let database: GamesDatabase?
    fileprivate let dataSource: RSTArrayTableViewDataSource<GameMetadata>
    
    fileprivate let operationQueue = RSTOperationQueue()
    fileprivate let imageCache = NSCache<NSURL, UIImage>()
    
    override init(style: UITableViewStyle) {
        fatalError()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        do
        {
            self.database = try GamesDatabase()
        }
        catch
        {
            self.database = nil
            print(error)
        }
        
        self.dataSource = RSTArrayTableViewDataSource<GameMetadata>(items: [])
        
        let titleText = NSLocalizedString("Games Database", comment: "")
        let detailText = NSLocalizedString("To search the database, type the name of a game in the search bar.", comment: "")
        
        let placeholderView = RSTBackgroundView()
        placeholderView.textLabel.text = titleText
        placeholderView.detailTextLabel.text = detailText
        self.dataSource.placeholderView = placeholderView
        
        super.init(coder: aDecoder)
        
        self.dataSource.cellConfigurationHandler = self.configure(cell:with:for:)
        
        if let database = self.database
        {
            self.dataSource.searchController.searchHandler = { [unowned database, unowned dataSource] (searchValue, previousSearchValue) in
                
                return RSTBlockOperation(executionBlock: { [unowned database, unowned dataSource] (operation) in
                    let results = database.metadataResults(forGameName: searchValue.text)
                    
                    guard !operation.isCancelled else { return }
                    
                    dataSource.items = results
                    
                    if searchValue.text == ""
                    {
                        rst_dispatch_sync_on_main_thread {
                            placeholderView.textLabel.text = titleText
                            placeholderView.detailTextLabel.text = detailText
                        }
                    }
                    else
                    {
                        rst_dispatch_sync_on_main_thread {
                            placeholderView.textLabel.text = NSLocalizedString("No Games Found", comment: "")
                            placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure the name is correct, or try searching for another game.", comment: "")
                        }
                    }
                })
            }
        }
        
        self.definesPresentationContext = true
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
        self.tableView.tableHeaderView = self.dataSource.searchController.searchBar
        self.tableView.rowHeight = 64
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    func configure(cell: UITableViewCell, with metadata: GameMetadata, for indexPath: IndexPath)
    {
        cell.textLabel?.text = metadata.name ?? NSLocalizedString("Unknown", comment: "")
        cell.textLabel?.numberOfLines = 2
        
        cell.imageView?.image = #imageLiteral(resourceName: "BoxArt")
        cell.imageView?.contentMode = .scaleAspectFit
        
        if let artworkURL = metadata.artworkURL
        {
            let operation = LoadImageURLOperation(url: artworkURL)
            operation.resultsCache = self.imageCache
            operation.resultHandler = { (image, error) in
                if let image = image
                {
                    DispatchQueue.main.async {
                        cell.imageView?.image = image
                        cell.imageView?.superview?.layoutIfNeeded()
                    }
                }
            }
            
            self.operationQueue.addOperation(operation, forKey: indexPath as NSIndexPath)
        }
    }
}

extension GamesDatabaseBrowserViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if self.dataSource.searchController.presentingViewController != nil
        {
            self.dataSource.searchController.dismiss(animated: true, completion: nil)
        }
        
        let metadata = self.dataSource.item(at: indexPath)
        self.selectionHandler?(metadata)
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let operation = self.operationQueue[indexPath as NSIndexPath]
        operation?.cancel()
    }
}
