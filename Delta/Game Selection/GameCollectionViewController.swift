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

import SDWebImage

class GameCollectionViewController: UICollectionViewController
{
    var gameCollection: GameCollection! {
        didSet {
            self.title = self.gameCollection.shortName
            self.updateDataSource()
        }
    }
    
    var theme: Theme = .opaque {
        didSet {
            // self.collectionView?.reloadData()
            
            // Calling reloadData sometimes will not update the cells correctly if an insertion/deletion animation is in progress
            // As a workaround, we manually iterate over and configure each cell ourselves
            for cell in self.collectionView?.visibleCells ?? []
            {
                if let indexPath = self.collectionView?.indexPath(for: cell)
                {
                    self.configure(cell as! GridCollectionViewCell, for: indexPath)
                }
                
            }
        }
    }
    
    weak var activeEmulatorCore: EmulatorCore?
    
    fileprivate var activeSaveState: SaveStateProtocol?
    
    fileprivate var dataSource: RSTFetchedResultsCollectionViewDataSource<Game>!
    fileprivate let prototypeCell = GridCollectionViewCell()
    
    fileprivate var _performing3DTouchTransition = false
    fileprivate weak var _destination3DTouchTransitionViewController: UIViewController?
    
    fileprivate var _renameAction: UIAlertAction?
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
        layout.minimumInteritemSpacing = 12
        
        self.registerForPreviewing(with: self, sourceView: self.collectionView!)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(GameCollectionViewController.handleLongPressGesture(_:)))
        self.collectionView?.addGestureRecognizer(longPressGestureRecognizer)
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showSaveStates":
            let game = sender as! Game
            
            let saveStatesViewController = (segue.destination as! UINavigationController).topViewController as! SaveStatesViewController
            saveStatesViewController.delegate = self
            saveStatesViewController.game = game
            saveStatesViewController.mode = .loading
            saveStatesViewController.theme = self.theme
            
        case "unwindFromGames":
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
            
        default: break
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
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath, ignoreImageOperations: Bool = false)
    {
        let game = self.dataSource.fetchedResultsController.object(at: indexPath)
        
        switch self.theme
        {
        case .opaque:
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
        case .translucent:
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
        }
        
        cell.maximumImageSize = CGSize(width: 90, height: 90)
        cell.textLabel.text = game.name
        cell.textLabel.textColor = UIColor.gray
        
        if let artworkURL = game.artworkURL, !ignoreImageOperations
        {
            cell.imageView.sd_setImage(with: artworkURL, placeholderImage: #imageLiteral(resourceName: "BoxArt"), options: .continueInBackground) { (image, error, type, url) in
                
                if let error = error
                {
                    print(error)
                }
                
                if image != nil
                {
                    cell.isImageViewVibrancyEnabled = false
                }
            }
        }
        else
        {
            cell.imageView.image = #imageLiteral(resourceName: "BoxArt")
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

//MARK: - Game Actions -
private extension GameCollectionViewController
{
    func actions(for game: Game) -> [Action]
    {
        let cancelAction = Action(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, action: nil)
        
        let renameAction = Action(title: NSLocalizedString("Rename", comment: ""), style: .default, action: { [unowned self] action in
            self.rename(game)
        })
        
        let shareAction = Action(title: NSLocalizedString("Share", comment: ""), style: .default, action: { [unowned self] action in
            self.share(game)
        })
        
        let saveStatesAction = Action(title: NSLocalizedString("Save States", comment: ""), style: .default, action: { [unowned self] action in
            self.viewSaveStates(for: game)
        })
        
        let deleteAction = Action(title: NSLocalizedString("Delete", comment: ""), style: .destructive, action: { [unowned self] action in
            self.delete(game)
        })
        
        switch game.type
        {
        case GameType.unknown: return [cancelAction, renameAction, shareAction, deleteAction]
        default: return [cancelAction, renameAction, shareAction, saveStatesAction, deleteAction]
        }
    }
    
    func delete(_ game: Game)
    {
        let confirmationAlertController = UIAlertController(title: NSLocalizedString("Are you sure you want to delete this game? All associated data, such as saves, save states, and cheat codes, will also be deleted.", comment: ""), message: nil, preferredStyle: .actionSheet)
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Delete Game", comment: ""), style: .destructive, handler: { action in
            
            DatabaseManager.shared.performBackgroundTask { (context) in
                let temporaryGame = context.object(with: game.objectID) as! Game
                context.delete(temporaryGame)
                
                context.saveWithErrorLogging()
            }
            
        }))
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(confirmationAlertController, animated: true, completion: nil)
    }
    
    func viewSaveStates(for game: Game)
    {
        self.performSegue(withIdentifier: "showSaveStates", sender: game)
    }
    
    func rename(_ game: Game)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Rename Game", comment: ""), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.text = game.name
            textField.placeholder = NSLocalizedString("Name", comment: "")
            textField.autocapitalizationType = .words
            textField.returnKeyType = .done
            textField.enablesReturnKeyAutomatically = true
            textField.addTarget(self, action: #selector(GameCollectionViewController.textFieldTextDidChange(_:)), for: .editingChanged)
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
            self._renameAction = nil
        }))
        
        let renameAction = UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { [unowned alertController] (action) in
            self.rename(game, with: alertController.textFields?.first?.text ?? "")
        })
        alertController.addAction(renameAction)
        self._renameAction = renameAction
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func rename(_ game: Game, with name: String)
    {
        guard name.characters.count > 0 else { return }

        DatabaseManager.shared.performBackgroundTask { (context) in
            let game = context.object(with: game.objectID) as! Game
            game.name = name
            
            context.saveWithErrorLogging()
        }
        
        self._renameAction = nil
    }
    
    func share(_ game: Game)
    {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let symbolicURL = temporaryDirectory.appendingPathComponent(game.name + "." + game.fileURL.pathExtension)
        
        do
        {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
            
            // Create a symbolic link so we can control the file name used when sharing.
            // Otherwise, if we just passed in game.fileURL to UIActivityViewController, the file name would be the game's SHA1 hash.
            try FileManager.default.createSymbolicLink(at: symbolicURL, withDestinationURL: game.fileURL)
        }
        catch
        {
            print(error)
        }
        
        let activityViewController = UIActivityViewController(activityItems: [symbolicURL], applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { (activityType, finished, returnedItems, error) in
            do
            {
                try FileManager.default.removeItem(at: temporaryDirectory)
            }
            catch
            {
                print(error)
            }
        }
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    @objc func textFieldTextDidChange(_ textField: UITextField)
    {
        let text = textField.text ?? ""
        self._renameAction?.isEnabled = text.characters.count > 0
    }
    
    @objc func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer)
    {
        guard gestureRecognizer.state == .began else { return }
        
        guard let indexPath = self.collectionView?.indexPathForItem(at: gestureRecognizer.location(in: self.collectionView)) else { return }
        
        let game = self.dataSource.fetchedResultsController.object(at: indexPath)
        let actions = self.actions(for: game)
        
        let alertController = UIAlertController(actions: actions)
        self.present(alertController, animated: true, completion: nil)
    }
}

//MARK: - UIViewControllerPreviewingDelegate -
/// UIViewControllerPreviewingDelegate
extension GameCollectionViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard self.gameCollection.identifier != GameType.unknown.rawValue else { return nil }
        
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
        
        let actions = self.actions(for: game).previewActions
        gameViewController.overridePreviewActionItems = actions
        
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

//MARK: - SaveStatesViewControllerDelegate -
/// SaveStatesViewControllerDelegate
extension GameCollectionViewController: SaveStatesViewControllerDelegate
{
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    {
    }
    
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateProtocol)
    {
        self.activeSaveState = saveState
        
        self.dismiss(animated: true) {
            let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: saveStatesViewController.game)!
            let cell = self.collectionView?.cellForItem(at: indexPath)
            
            self.launchGame(withSender: cell, clearScreen: false)
        }
    }
}

//MARK: - UICollectionViewDelegate -
/// UICollectionViewDelegate
extension GameCollectionViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        guard self.gameCollection.identifier != GameType.unknown.rawValue else { return }
        
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
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        let cell = cell as! GridCollectionViewCell
        cell.imageView.sd_cancelCurrentImageLoad()
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
        
        self.configure(self.prototypeCell, for: indexPath, ignoreImageOperations: true)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size
    }
}
