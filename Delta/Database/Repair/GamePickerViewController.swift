//
//  GamePickerViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/4/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class GamePickerViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    var gameHandler: ((Game?) -> Void)?
    
    init()
    {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.navigationController?.delegate = self
        
        self.dataSource.proxy = self
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.navigationItem.title = NSLocalizedString("Choose Game", comment: "")
        self.navigationItem.searchController = self.dataSource.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
    }
}

private extension GamePickerViewController
{
    func makeDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<Game, UIImage>
    {
        let fetchRequest = Game.fetchRequest()
        fetchRequest.propertiesToFetch = [#keyPath(Game.name), #keyPath(Game.identifier), #keyPath(Game.artworkURL)]
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.gameCollection?.index, ascending: true), NSSortDescriptor(keyPath: \Game.name, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(Game.gameCollection.name), cacheName: nil)
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<Game, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.cellConfigurationHandler = { (cell, game, indexPath) in
            var configuration = UIListContentConfiguration.valueCell()
            configuration.prefersSideBySideTextAndSecondaryText = false
            
            configuration.text = game.name
            
            configuration.secondaryText = game.identifier
            configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
            
            configuration.image = UIImage(resource: .boxArt)
            configuration.imageProperties.maximumSize = CGSize(width: 48, height: 48)
            configuration.imageProperties.reservedLayoutSize = CGSize(width: 48, height: 48)
            configuration.imageProperties.cornerRadius = 4
            
            cell.contentConfiguration = configuration
        }
        dataSource.prefetchHandler = { (game, indexPath, completionHandler) in
            guard let artworkURL = game.artworkURL else {
                completionHandler(nil, nil)
                return nil
            }
            
            let imageOperation = LoadImageURLOperation(url: artworkURL)
            imageOperation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
            
            return imageOperation
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image, var config = cell.contentConfiguration as? UIListContentConfiguration else { return }
            config.image = image
            cell.contentConfiguration = config
        }
        
        dataSource.searchController.searchableKeyPaths = [#keyPath(Game.name), #keyPath(Game.identifier)]
        
        return dataSource
    }
}

extension GamePickerViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let game = self.dataSource.item(at: indexPath)
        self.gameHandler?(game)
        
        self.navigationController?.delegate = nil // Prevent calling navigationController(_:willShow:)
        self.navigationController?.popViewController(animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard let section = self.dataSource.fetchedResultsController.sections?[section], !section.name.isEmpty else {
            return NSLocalizedString("Unknown System", comment: "")
        }
        
        return section.name
    }
}

extension GamePickerViewController: UINavigationControllerDelegate
{
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool)
    {
        guard viewController != self else { return }
        
        self.gameHandler?(nil)
    }
}
