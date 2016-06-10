//
//  ViewController.swift
//  DeltaTV
//
//  Created by Riley Testut on 9/26/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import Roxas

class GameSelectionViewController: UICollectionViewController
{
    private let dataSource = GameCollectionViewDataSource()
    private var backgroundView: RSTBackgroundView! = nil
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.title = NSLocalizedString("Games", comment: "")
        
        self.dataSource.supportedGameCollectionIdentifiers = [kUTTypeSNESGame as String, kUTTypeGBAGame as String]
        self.dataSource.fetchedResultsController.delegate = self
        self.dataSource.cellConfigurationHandler = self.configureCell
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.delegate = self.dataSource
                
        if let layout = self.collectionViewLayout as? GridCollectionViewLayout
        {
            layout.itemWidth = 200
        }
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Games", comment: "")
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can import games by pressing the + button in the top right.", comment: "")
        self.view.addSubview(self.backgroundView)
    }
    
    override func viewWillAppear(animated: Bool)
    {
        self.dataSource.update()
        self.updateCollections()
        
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
    
    private func configureCell(cell: GridCollectionViewCell, game: Game)
    {
        cell.maximumImageSize = CGSize(width: 200, height: 200)
        
        cell.textLabel.font = UIFont.boldSystemFontOfSize(30)
        cell.textLabel.text = game.name
        
        cell.imageView.image = UIImage(named: "BoxArt")
    }
}

private extension GameSelectionViewController
{
    func updateCollections()
    {
        if self.dataSource.fetchedResultsController.sections?.count ?? 0 == 0
        {
            self.backgroundView.hidden = false
            self.collectionView?.hidden = true
        }
        else
        {
            self.backgroundView.hidden = true
            self.collectionView?.hidden = false
        }
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
        
        self.updateCollections()
    }
}

