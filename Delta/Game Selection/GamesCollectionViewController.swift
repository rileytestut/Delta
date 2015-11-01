//
//  GamesCollectionViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore

class GamesCollectionViewController: UICollectionViewController
{
    var gameTypeIdentifier: String! {
        didSet
        {
            self.dataSource.gameTypeIdentifiers = [self.gameTypeIdentifier]
        }
    }
    
    private let dataSource = GameCollectionViewDataSource()
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.dataSource.fetchedResultsController.delegate = self
        self.dataSource.cellConfigurationHandler = self.configureCell
    }
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.delegate = self.dataSource
        
        if let layout = self.collectionViewLayout as? GameCollectionViewLayout
        {
            layout.maximumBoxArtSize = CGSize(width: 100, height: 100)
        }
    }
    
    override func viewWillAppear(animated: Bool)
    {
        self.dataSource.update()
        
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation -
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let viewController = segue.destinationViewController as? EmulationViewController else { return }
        
        let indexPath = self.collectionView?.indexPathsForSelectedItems()?.first
        let game = self.dataSource.fetchedResultsController.objectAtIndexPath(indexPath!) as! Game
        
        viewController.game = game
    }
    
    // MARK: - Collection View -
    
    private func configureCell(cell: GameCollectionViewCell, game: Game)
    {
        cell.nameLabel.text = game.name
    }
}

extension GamesCollectionViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.collectionView?.reloadData()
    }
}
