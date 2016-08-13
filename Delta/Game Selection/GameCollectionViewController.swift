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
    
    weak var activeEmulatorCore: EmulatorCore?
    
    private var activeSaveState: SaveStateProtocol?
    
    private var dataSource: RSTFetchedResultsCollectionViewDataSource<Game>!
    private let prototypeCell = GridCollectionViewCell()
    
    private var _performing3DTouchTransition = false
    private weak var _destination3DTouchTransitionViewController: UIViewController?
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
        
        self.registerForPreviewing(with: self, sourceView: self.collectionView!)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.dataSource.fetchedResultsController.performFetchIfNeeded()
        
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if _performing3DTouchTransition
        {
            _performing3DTouchTransition = false
            
            // Unlike our custom transitions, 3D Touch transition doesn't manually call appearance methods for us
            // To compensate, we call them ourselves
            _destination3DTouchTransitionViewController?.beginAppearanceTransition(true, animated: true)
            
            self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                self._destination3DTouchTransitionViewController?.endAppearanceTransition()
                self._destination3DTouchTransitionViewController = nil
            })
        }
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
        
        if let saveState = self.activeSaveState
        {
            // Must be synchronous or else there will be a flash of black
            destinationViewController.emulatorCore?.start()
            destinationViewController.emulatorCore?.pause()
            
            do
            {
                try destinationViewController.emulatorCore?.load(saveState)
            }
            catch EmulatorCore.SaveStateError.doesNotExist
            {
                print("Save State does not exist.")
            }
            catch
            {
                print(error)
            }
            
            destinationViewController.emulatorCore?.resume()
        }
        
        self.activeSaveState = nil
        
        if _performing3DTouchTransition
        {
            _destination3DTouchTransitionViewController = destinationViewController
        }
    }
}

//MARK: - Private Methods -
private extension GameCollectionViewController
{
    //MARK: - Update
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
    
    //MARK: - Configure Cells
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
    
    //MARK: - Emulation
    func launchGame(withSender sender: AnyObject?, clearScreen: Bool)
    {
        if clearScreen
        {
            self.activeEmulatorCore?.gameViews.forEach { $0.inputImage = nil }
        }
        
        self.performSegue(withIdentifier: "unwindFromGames", sender: sender)
    }
}

//MARK: - UIViewControllerPreviewingDelegate -
/// UIViewControllerPreviewingDelegate
extension GameCollectionViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let collectionView = self.collectionView,
            let indexPath = collectionView.indexPathForItem(at: location),
            let layoutAttributes = collectionView.layoutAttributesForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = layoutAttributes.frame
        
        let game = self.dataSource.fetchedResultsController.object(at: indexPath)
        
        let gameViewController = PreviewGameViewController()
        gameViewController.game = game
        
        if let previewSaveState = game.previewSaveState
        {
            gameViewController.previewSaveState = previewSaveState
            gameViewController.previewImage = UIImage(contentsOfFile: previewSaveState.imageFileURL.path)
        }
        
        return gameViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        let gameViewController = viewControllerToCommit as! PreviewGameViewController
        let game = gameViewController.game as! Game
        
        let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: game)!
        let cell = self.collectionView?.cellForItem(at: indexPath)
        
        let fileURL = FileManager.uniqueTemporaryURL()
        self.activeSaveState = gameViewController.emulatorCore?.saveSaveState(to: fileURL)
        
        gameViewController.emulatorCore?.stop()
        
        _performing3DTouchTransition = true
        
        self.launchGame(withSender: cell, clearScreen: true)
        
        do
        {
            try FileManager.default.removeItem(at: fileURL)
        }
        catch
        {
            print(error)
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
        
        if game.fileURL == self.activeEmulatorCore?.game.fileURL
        {
            let alertController = UIAlertController(title: NSLocalizedString("Game Paused", comment: ""), message: NSLocalizedString("Would you like to resume where you left off, or restart the game?", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Resume", comment: ""), style: .default, handler: { (action) in
                
                let fetchRequest = SaveState.rst_fetchRequest() as! NSFetchRequest<SaveState>
                fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %d", #keyPath(SaveState.game), game, #keyPath(SaveState.type), SaveStateType.auto.rawValue)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: true)]
                
                do
                {
                    let saveStates = try game.managedObjectContext?.fetch(fetchRequest)
                    self.activeSaveState = saveStates?.last
                }
                catch
                {
                    print(error)
                }
                
                // Disable videoManager to prevent flash of black
                self.activeEmulatorCore?.videoManager.isEnabled = false
                
                self.launchGame(withSender: cell, clearScreen: false)
                
                // The game hasn't changed, so the activeEmulatorCore is the same as before, so we need to enable videoManager it again
                self.activeEmulatorCore?.videoManager.isEnabled = true
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Restart", comment: ""), style: .destructive, handler: { (action) in
                self.launchGame(withSender: cell, clearScreen: true)
            }))
            self.present(alertController, animated: true)
        }
        else
        {
            self.launchGame(withSender: cell, clearScreen: true)
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
