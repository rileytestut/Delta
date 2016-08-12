//
//  GameCollectionViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import Roxas

class GameCollectionViewController: UICollectionViewController
{
    var gameCollection: GameCollection! {
        didSet {
            self.title = self.gameCollection.shortName
            self.updateDataSource()
        }
    }
    
    var theme: GamesViewController.Theme = .light {
        didSet {
            self.collectionView?.reloadData()
        }
    }
    
    var activeEmulatorCore: EmulatorCore?
    
    private var dataSource: RSTFetchedResultsCollectionViewDataSource<Game>!
    private let prototypeCell = GridCollectionViewCell()
}

//MARK: - UIViewController -
/// UIViewController
extension GameCollectionViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.delegate = self
        
        let layout = self.collectionViewLayout as! GridCollectionViewLayout
        layout.itemWidth = 90
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.dataSource.fetchedResultsController.performFetchIfNeeded()
        
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

//MARK: - Segues -
/// Segues
extension GameCollectionViewController
{
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let identifier = segue.identifier, identifier == "unwindFromGames" else { return }
        
        let destinationViewController = segue.destination as! GameViewController
        let cell = sender as! UICollectionViewCell
        
        let indexPath = self.collectionView?.indexPath(for: cell)
        let game = self.dataSource.fetchedResultsController.object(at: indexPath!)
        
        destinationViewController.game = game
    }
}

//MARK: - Configure Cells -
/// Configure Cells
private extension GameCollectionViewController
{
    func updateDataSource()
    {
        let fetchRequest = Game.rst_fetchRequest() as! NSFetchRequest<Game>
        fetchRequest.predicate = NSPredicate(format: "ANY %K == %@", #keyPath(Game.gameCollections), self.gameCollection)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Game.name), ascending: true)]
        
        self.dataSource = RSTFetchedResultsCollectionViewDataSource(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        self.dataSource.cellIdentifierHandler = { _ in RSTGenericCellIdentifier }
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, indexPath) in
            self.configure(cell as! GridCollectionViewCell, for: indexPath)
        }
    }
}

//MARK: - Configure Cells -
/// Configure Cells
private extension GameCollectionViewController
{
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath)
    {
        let game = self.dataSource.fetchedResultsController.object(at: indexPath)
        
        cell.maximumImageSize = CGSize(width: 90, height: 90)
        cell.textLabel.text = game.name
        cell.imageView.image = UIImage(named: "BoxArt")
        
        switch self.theme
        {
        case .light:
            cell.textLabel.textColor = UIColor.darkText
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
        case .dark:
            cell.textLabel.textColor = UIColor.white
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
        }
    }
}

//MARK: - UICollectionViewDelegate -
/// UICollectionViewDelegate
extension GameCollectionViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let cell = collectionView.cellForItem(at: indexPath)
        let game = self.dataSource.fetchedResultsController.object(at: indexPath)
        
        func launchGame(clearScreen: Bool)
        {
            if clearScreen
            {
                self.activeEmulatorCore?.gameViews.forEach({ $0.inputImage = nil })
            }
            
            self.performSegue(withIdentifier: "unwindFromGames", sender: cell)
        }
        
        if game.fileURL == self.activeEmulatorCore?.game.fileURL
        {
            let alertController = UIAlertController(title: NSLocalizedString("Game Paused", comment: ""), message: NSLocalizedString("Would you like to resume where you left off, or restart the game?", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Resume", comment: ""), style: .default, handler: { (action) in
                launchGame(clearScreen: false)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Restart", comment: ""), style: .destructive, handler: { (action) in
                self.activeEmulatorCore?.stop()
                launchGame(clearScreen: true)
            }))
            self.present(alertController, animated: true)
        }
        else
        {
            launchGame(clearScreen: true)
        }
    }
}

//MARK: - UICollectionViewDelegateFlowLayout -
/// UICollectionViewDelegateFlowLayout
extension GameCollectionViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let collectionViewLayout = collectionView.collectionViewLayout as! GridCollectionViewLayout
        
        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionViewLayout.itemWidth)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }
        
        self.configure(self.prototypeCell, for: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size
    }
}
