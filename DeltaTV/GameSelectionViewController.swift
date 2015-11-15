//
//  ViewController.swift
//  DeltaTV
//
//  Created by Riley Testut on 9/26/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import SNESDeltaCore

class GameSelectionViewController: UICollectionViewController
{
    private let dataSource = GameCollectionViewDataSource()
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.title = NSLocalizedString("Games", comment: "")
        
        self.dataSource.gameTypeIdentifiers = [kUTTypeSNESGame as String]
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
            layout.maximumBoxArtSize = CGSize(width: 200, height: 200)
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
    
    // MARK: - Importing -
    
    @IBAction func importFiles()
    {
        let gamePickerController = GamePickerController()
        gamePickerController.delegate = self
        self.presentGamePickerController(gamePickerController, animated: true, completion: nil)
    }
    
    
    // MARK: - Navigation -
    
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
        cell.nameLabel.font = UIFont.boldSystemFontOfSize(30)
        cell.nameLabel.text = game.name
    }
}

// MARK: - <GamePickerControllerDelegate> -
extension GameSelectionViewController: GamePickerControllerDelegate
{
    func gamePickerController(gamePickerController: GamePickerController, didImportGames games: [Game])
    {
        print(games)
    }
}

extension GameSelectionViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.collectionView?.reloadData()
    }
}

