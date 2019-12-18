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
    
    private let database: GamesDatabase?
    
    private let dataSource: RSTArrayTableViewPrefetchingDataSource<GameMetadata, UIImage>
    
    override init(style: UITableView.Style) {
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
        
        self.dataSource = RSTArrayTableViewPrefetchingDataSource<GameMetadata, UIImage>(items: [])
        
        super.init(coder: aDecoder)
        
        self.definesPresentationContext = true
        
        self.prepareDataSource()
    }
    
    #if os(iOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.deltaDarkGray
        
        self.tableView.register(GameTableViewCell.nib!, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        
        self.tableView.indicatorStyle = .white
        #if os(iOS)
        self.tableView.separatorColor = UIColor.gray
        #endif
        
        self.dataSource.searchController.delegate = self
        #if os(iOS)
        self.dataSource.searchController.searchBar.barStyle = .black
        
        self.navigationItem.searchController = self.dataSource.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        #endif
        
        self.updatePlaceholderView()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.dataSource.searchController.isActive = true
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

private extension GamesDatabaseBrowserViewController
{
    func prepareDataSource()
    {
        /* Placeholder View */
        let placeholderView = RSTPlaceholderView()
        #if os(iOS)
        placeholderView.textLabel.textColor = UIColor.lightText
        placeholderView.detailTextLabel.textColor = UIColor.lightText
        #else
        placeholderView.textLabel.textColor = UIColor.lightGray
        placeholderView.detailTextLabel.textColor = UIColor.lightGray
        #endif
        self.dataSource.placeholderView = placeholderView
        
        
        /* Cell Configuration */
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, metadata, indexPath) in
            self.configure(cell: cell as! GameTableViewCell, with: metadata, for: indexPath)
        }
        
        
        /* Prefetching */
        self.dataSource.prefetchHandler = { (metadata, indexPath, completionHandler) in
            guard let artworkURL = metadata.artworkURL else { return nil }
            
            let operation = LoadImageURLOperation(url: artworkURL)
            operation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
            return operation
        }

        self.dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image else { return }
            
            let cell = cell as! GameTableViewCell
            
            let artworkDisplaySize = AVMakeRect(aspectRatio: image.size, insideRect: cell.artworkImageView.bounds)
            let offset = (cell.artworkImageView.bounds.width - artworkDisplaySize.width) / 2
            
            // Offset artworkImageViewLeadingConstraint and artworkImageViewTrailingConstraint to right-align artworkImageView
            cell.artworkImageViewLeadingConstraint.constant += offset
            cell.artworkImageViewTrailingConstraint.constant -= offset
            
            cell.artworkImageView.image = image
            cell.artworkImageView.superview?.layoutIfNeeded()
        }
        
        
        /* Searching */
        if let database = self.database
        {
            self.dataSource.searchController.searchHandler = { [unowned self, unowned database] (searchValue, previousSearchValue) in
                return RSTBlockOperation() { [unowned self, unowned database] (operation) in
                    let results = database.metadataResults(forGameName: searchValue.text)
                    
                    guard !operation.isCancelled else { return }
                    
                    self.dataSource.items = results
                    
                    rst_dispatch_sync_on_main_thread {
                        self.resetTableViewContentOffset()
                        self.updatePlaceholderView()
                    }
                }
            }
        }
    }
}

private extension GamesDatabaseBrowserViewController
{
    func configure(cell: GameTableViewCell, with metadata: GameMetadata, for indexPath: IndexPath)
    {
        cell.backgroundColor = UIColor.deltaDarkGray
        
        cell.nameLabel.text = metadata.name ?? NSLocalizedString("Unknown", comment: "")
        cell.artworkImageView.image = #imageLiteral(resourceName: "BoxArt")
        
        cell.artworkImageViewLeadingConstraint.constant = 15
        cell.artworkImageViewTrailingConstraint.constant = 15
        
        #if os(iOS)
        cell.separatorInset.left = cell.nameLabel.frame.minX
        #endif
    }
    
    func updatePlaceholderView()
    {
        guard let placeholderView = self.dataSource.placeholderView as? RSTPlaceholderView else { return }
        
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
    
    func resetTableViewContentOffset()
    {
        self.tableView.setContentOffset(CGPoint.zero, animated: false)
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.view.safeAreaInsets.top), animated: false)
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
}

extension GamesDatabaseBrowserViewController: UISearchControllerDelegate
{
    func didPresentSearchController(_ searchController: UISearchController)
    {
        DispatchQueue.main.async {
            searchController.searchBar.becomeFirstResponder()
        }
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
        self.resetTableViewContentOffset()
    }
}
