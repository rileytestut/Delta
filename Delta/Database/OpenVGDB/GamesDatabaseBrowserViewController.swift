//
//  GamesDatabaseBrowserViewController.swift
//  Delta
//
//  Created by Riley Testut on 2/6/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

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
        
        let placeholderView = RSTBackgroundView()
        placeholderView.textLabel.textColor = UIColor.lightText
        placeholderView.detailTextLabel.textColor = UIColor.lightText
        
        self.dataSource.placeholderView = placeholderView
        
        super.init(coder: aDecoder)
        
        self.dataSource.cellConfigurationHandler = { (cell, metadata, indexPath) in
            self.configure(cell: cell as! GameMetadataTableViewCell, with: metadata, for: indexPath)
        }
        
        if let database = self.database
        {
            self.dataSource.searchController.searchHandler = { [unowned database, unowned dataSource] (searchValue, previousSearchValue) in
                
                return RSTBlockOperation(executionBlock: { [unowned database, unowned dataSource] (operation) in
                    let results = database.metadataResults(forGameName: searchValue.text)
                    
                    guard !operation.isCancelled else { return }
                    
                    dataSource.items = results
                    
                    rst_dispatch_sync_on_main_thread {
                        self.updatePlaceholderView()
                    }
                })
            }
        }
        
        self.definesPresentationContext = true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.deltaDarkGray
        
        self.tableView.dataSource = self.dataSource
        self.tableView.indicatorStyle = .white
        self.tableView.separatorColor = UIColor.gray
        
        self.dataSource.searchController.delegate = self
        self.dataSource.searchController.searchBar.barStyle = .blackTranslucent
        self.tableView.tableHeaderView = self.dataSource.searchController.searchBar
        
        self.updatePlaceholderView()
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

extension GamesDatabaseBrowserViewController
{
    func configure(cell: GameMetadataTableViewCell, with metadata: GameMetadata, for indexPath: IndexPath)
    {
        cell.backgroundColor = UIColor.deltaDarkGray
        
        cell.nameLabel.text = metadata.name ?? NSLocalizedString("Unknown", comment: "")
        cell.artworkImageView.image = #imageLiteral(resourceName: "BoxArt")
        
        cell.artworkImageViewLeadingConstraint.constant = 15
        cell.artworkImageViewTrailingConstraint.constant = 15
        
        cell.separatorInset.left = cell.nameLabel.frame.minX
        
        if let artworkURL = metadata.artworkURL
        {
            let operation = LoadImageURLOperation(url: artworkURL)
            operation.resultsCache = self.imageCache
            operation.resultHandler = { (image, error) in
                if let image = image
                {
                    let artworkDisplaySize = AVMakeRect(aspectRatio: image.size, insideRect: cell.artworkImageView.bounds)
                    let offset = (cell.artworkImageView.bounds.width - artworkDisplaySize.width) / 2
                    
                    DispatchQueue.main.async {
                        // Offset artworkImageViewLeadingConstraint and artworkImageViewTrailingConstraint to right-align artworkImageView
                        cell.artworkImageViewLeadingConstraint.constant += offset
                        cell.artworkImageViewTrailingConstraint.constant -= offset
                        
                        cell.artworkImageView.image = image
                        cell.artworkImageView.superview?.layoutIfNeeded()
                    }
                }
            }
            
            self.operationQueue.addOperation(operation, forKey: indexPath as NSIndexPath)
        }
    }
    
    func updatePlaceholderView()
    {
        guard let placeholderView = self.dataSource.placeholderView as? RSTBackgroundView else { return }
        
        if self.dataSource.searchController.searchBar.text == ""
        {
            placeholderView.textLabel.text = NSLocalizedString("Games Database", comment: "")
            placeholderView.detailTextLabel.text = NSLocalizedString("To search the database, type the name of a game in the search bar.", comment: "")
        }
        else
        {
            placeholderView.textLabel.text = NSLocalizedString("No Games Found", comment: "")
            placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure the name is correct, or try searching for another game.", comment: "")
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

extension GamesDatabaseBrowserViewController: UISearchControllerDelegate
{
    func didPresentSearchController(_ searchController: UISearchController)
    {
        // Fix incorrect table view scroll indicator insets
        self.tableView.scrollIndicatorInsets.top = self.navigationController!.navigationBar.bounds.height + UIApplication.shared.statusBarFrame.height
    }
    
    func willDismissSearchController(_ searchController: UISearchController)
    {
        // Manually set items to empty array to prevent crash if user dismissses searchController while scrolling
        self.dataSource.items = []
        self.updatePlaceholderView()
    }
    
    func didDismissSearchController(_ searchController: UISearchController)
    {
        // Fix potentially incorrect offset if user dismisses searchController while scrolling
        self.tableView.setContentOffset(CGPoint.zero, animated: false)
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.topLayoutGuide.length), animated: false)
    }
}
