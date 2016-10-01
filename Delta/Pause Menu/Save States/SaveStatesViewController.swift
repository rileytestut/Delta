//
//  SaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/23/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore
import Roxas

protocol SaveStatesViewControllerDelegate: class
{
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    func saveStatesViewController(_ saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateProtocol)
}

extension SaveStatesViewController
{
    enum Mode
    {
        case saving
        case loading
    }
    
    enum Section: Int
    {
        case auto
        case general
        case locked
    }
}

class SaveStatesViewController: UICollectionViewController
{
    var game: Game! {
        didSet {
            self.updateFetchedResultsController()
        }
    }
    
    // Reference to a current EmulatorCore. emulatorCore.game does _not_ have to match self.game
    var emulatorCore: EmulatorCore?
    
    weak var delegate: SaveStatesViewControllerDelegate?
    
    var mode = Mode.loading
    
    var theme = Theme.dark {
        didSet {
            if self.isViewLoaded
            {
                self.updateTheme()
            }
        }
    }
        
    fileprivate var vibrancyView: UIVisualEffectView!
    fileprivate var backgroundView: RSTBackgroundView!
    
    fileprivate var prototypeCell = GridCollectionViewCell()
    fileprivate var prototypeCellWidthConstraint: NSLayoutConstraint!
    fileprivate var prototypeHeader = SaveStatesCollectionHeaderView()
    
    fileprivate var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>!
    
    fileprivate let imageOperationQueue = RSTOperationQueue()
    fileprivate let imageCache = NSCache<NSURL, UIImage>()
    
    fileprivate var emulatorCoreSaveState: SaveStateProtocol?
    fileprivate var selectedSaveState: SaveState?
    
    fileprivate let dateFormatter: DateFormatter
    
    required init?(coder aDecoder: NSCoder)
    {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.timeStyle = .short
        self.dateFormatter.dateStyle = .short
        
        super.init(coder: aDecoder)
    }
}

extension SaveStatesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.vibrancyView = UIVisualEffectView(effect: nil)
        self.vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.vibrancyView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        self.view.insertSubview(self.vibrancyView, at: 0)
        
        self.backgroundView = RSTBackgroundView(frame: CGRect(x: 0, y: 0, width: vibrancyView.bounds.width, height: vibrancyView.bounds.height))
        self.backgroundView.isHidden = true
        self.backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.white
        self.backgroundView.detailTextLabel.textColor = UIColor.white
        self.vibrancyView.contentView.addSubview(self.backgroundView)
        
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        let averageHorizontalInset = (collectionViewLayout.sectionInset.left + collectionViewLayout.sectionInset.right) / 2
        let portraitScreenWidth = UIScreen.main.coordinateSpace.convert(UIScreen.main.bounds, to: UIScreen.main.fixedCoordinateSpace).width
        
        // Use dimensions that allow two cells to fill the screen horizontally with padding in portrait mode
        // We'll keep the same size for landscape orientation, which will allow more to fit
        collectionViewLayout.itemWidth = (portraitScreenWidth - (averageHorizontalInset * 3)) / 2
        
        switch self.mode
        {
        case .saving:
            self.title = NSLocalizedString("Save State", comment: "")
            self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
            
        case .loading:
            self.title = NSLocalizedString("Load State", comment: "")
            self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the Save State option in the pause menu.", comment: "")
            self.navigationItem.rightBarButtonItem = nil
        }
        
        // Manually update prototype cell properties
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionViewLayout.itemWidth)
        self.prototypeCellWidthConstraint.isActive = true
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SaveStatesViewController.handleLongPressGesture(_:)))
        self.collectionView?.addGestureRecognizer(longPressGestureRecognizer)

        self.prepareEmulatorCoreSaveState()
        
        self.registerForPreviewing(with: self, sourceView: self.collectionView!)
        
        self.updateBackgroundView()
        self.updateTheme()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.fetchedResultsController.performFetchIfNeeded()
        
        self.updateBackgroundView()
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        self.resetEmulatorCoreIfNeeded()
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

private extension SaveStatesViewController
{
    //MARK: - Update -
    
    func updateFetchedResultsController()
    {
        let fetchRequest = SaveState.rst_fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SaveState.Attributes.game.rawValue, self.game)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: SaveState.Attributes.type.rawValue, ascending: true), NSSortDescriptor(key: SaveState.Attributes.creationDate.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: SaveState.Attributes.type.rawValue, cacheName: nil)
        self.fetchedResultsController.delegate = self
    }
    
    func updateBackgroundView()
    {
        if let fetchedObjects = self.fetchedResultsController.fetchedObjects, fetchedObjects.count > 0
        {
            self.backgroundView.isHidden = true
        }
        else
        {
            self.backgroundView.isHidden = false
        }
    }
    
    func updateTheme()
    {
        switch self.theme
        {
        case .light:
            self.view.backgroundColor = UIColor.white
            
            self.navigationController?.navigationBar.barStyle = .default
            self.navigationController?.toolbar.barStyle = .default
            
            self.vibrancyView.effect = nil
            
            self.backgroundView.textLabel.textColor = UIColor.gray
            self.backgroundView.detailTextLabel.textColor = UIColor.gray
            
        case .dark:
            self.view.backgroundColor = nil
            
            self.navigationController?.navigationBar.barStyle = .blackTranslucent
            self.navigationController?.toolbar.barStyle = .blackTranslucent
            
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark))
            
            self.backgroundView.textLabel.textColor = UIColor.white
            self.backgroundView.detailTextLabel.textColor = UIColor.white
        }
    }
    
    //MARK: - Configure Views -
    
    func configureCollectionViewCell(_ cell: GridCollectionViewCell, forIndexPath indexPath: IndexPath, ignoreExpensiveOperations ignoreOperations: Bool = false)
    {
        let saveState = self.fetchedResultsController.object(at: indexPath) as! SaveState
        
        cell.imageView.backgroundColor = UIColor.white
        cell.imageView.image = UIImage(named: "DeltaPlaceholder")
        
        switch self.theme
        {
        case .light:
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
            cell.textLabel.textColor = UIColor.gray
            
        case .dark:
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
            
            cell.textLabel.textColor = UIColor.white
        }        
        
        if !ignoreOperations
        {
            let imageOperation = LoadImageOperation(URL: saveState.imageFileURL)
            imageOperation.imageCache = self.imageCache
            imageOperation.completionHandler = { image in
                
                if let image = image
                {
                    cell.imageView.backgroundColor = nil
                    cell.imageView.image = image
                    
                    cell.isImageViewVibrancyEnabled = false
                }
            }
            
            // Ensure initially visible cells have loaded their image before they appear to prevent potential flickering from placeholder to thumbnail
            if self.isAppearing
            {
                imageOperation.isImmediate = true
            }
            
            self.imageOperationQueue.addOperation(imageOperation, forKey: indexPath as NSCopying)
        }
        
        let deltaCore = Delta.core(for: self.game.type)!
        
        let dimensions = deltaCore.emulatorConfiguration.videoBufferInfo.outputDimensions
        cell.maximumImageSize = CGSize(width: self.prototypeCellWidthConstraint.constant, height: (self.prototypeCellWidthConstraint.constant / dimensions.width) * dimensions.height)
        
        cell.textLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        
        let name = saveState.name ?? self.dateFormatter.string(from: saveState.modifiedDate)
        cell.textLabel.text = name
    }
    
    func configureCollectionViewHeaderView(_ headerView: SaveStatesCollectionHeaderView, forSection section: Int)
    {
        let section = self.correctedSectionForSectionIndex(section)
        
        let title: String
        
        switch section
        {
        case .auto: title = NSLocalizedString("Auto Save", comment: "")
        case .general: title = NSLocalizedString("General", comment: "")
        case .locked: title = NSLocalizedString("Locked", comment: "")
        }
        
        headerView.textLabel.text = title
        
        switch self.theme
        {
        case .light:
            headerView.textLabel.textColor = UIColor.gray
            headerView.isTextLabelVibrancyEnabled = false
            
        case .dark:
            headerView.textLabel.textColor = UIColor.white
            headerView.isTextLabelVibrancyEnabled = true
        }
    }
    
    //MARK: - Gestures -
    
    @objc func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer)
    {
        guard gestureRecognizer.state == .began else { return }
        
        guard let indexPath = self.collectionView?.indexPathForItem(at: gestureRecognizer.location(in: self.collectionView)) else { return }
        
        let saveState = self.fetchedResultsController.object(at: indexPath) as! SaveState
        
        guard let actions = self.actionsForSaveState(saveState) else { return }
        
        let alertController = UIAlertController(actions: actions)
        self.present(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Save States -
    
    @IBAction func addSaveState()
    {
        var saveState: SaveState!
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            
            let game = backgroundContext.object(with: self.game.objectID) as! Game
            
            saveState = SaveState.insertIntoManagedObjectContext(backgroundContext)
            saveState.game = game
        }
        
        self.updateSaveState(saveState)
    }
    
    func updateSaveState(_ saveState: SaveState)
    {
        // Switch back to self.emulatorCore
        self.prepareEmulatorCore()
        
        saveState.managedObjectContext?.performAndWait {
            self.delegate?.saveStatesViewController(self, updateSaveState: saveState)
            saveState.managedObjectContext?.saveWithErrorLogging()
        }
    }
    
    func loadSaveState(_ saveState: SaveStateProtocol)
    {
        // Stop previewGameViewController.emulatorCore, and switch to self.emulatorCore
        self.prepareEmulatorCore()
        
        self.delegate?.saveStatesViewController(self, loadSaveState: saveState)
        
        // Implicit assumption that loadSaveState will always result in SaveStatesViewController being dismissed
        // Mostly because the method used in updateSaveState(_:) to detect this doesn't work for peek/pop, and too lazy to care rn
    }
    
    func deleteSaveState(_ saveState: SaveState)
    {
        let confirmationAlertController = UIAlertController(title: NSLocalizedString("Delete Save State?", comment: ""), message: NSLocalizedString("Are you sure you want to delete this save state? This cannot be undone.", comment: ""), preferredStyle: .alert)
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .default, handler: { action in
            
            DatabaseManager.shared.performBackgroundTask { (context) in
                let temporarySaveState = context.object(with: saveState.objectID)
                context.delete(temporarySaveState)
                context.saveWithErrorLogging()
            }
            
        }))
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(confirmationAlertController, animated: true, completion: nil)
    }
    
    func renameSaveState(_ saveState: SaveState)
    {
        self.selectedSaveState = saveState
        
        let alertController = UIAlertController(title: NSLocalizedString("Rename Save State", comment: ""), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.text = saveState.name
            textField.placeholder = NSLocalizedString("Name", comment: "")
            textField.autocapitalizationType = .words
            textField.returnKeyType = .done
            textField.addTarget(self, action: #selector(SaveStatesViewController.updateSaveStateName(_:)), for: .editingDidEnd)
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
            self.selectedSaveState = nil
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { (action) in
            self.updateSaveStateName(alertController.textFields!.first!)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func updateSaveStateName(_ textField: UITextField)
    {
        guard let selectedSaveState = self.selectedSaveState else { return }
        
        var text = textField.text
        if text?.characters.count == 0
        {
            // When text is nil, we know to show the timestamp instead
            text = nil
        }
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            let saveState = context.object(with: selectedSaveState.objectID) as! SaveState
            saveState.name = text
            
            context.saveWithErrorLogging()
        }
        
        self.selectedSaveState = nil
    }
    
    func updatePreviewSaveState(_ saveState: SaveState?)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Change Preview Save State?", comment: ""), message: NSLocalizedString("The Preview Save State is loaded whenever you preview this game from the Main Menu with 3D Touch. Are you sure you want to change it?", comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Change", comment: ""), style: .default, handler: { (action) in
            
            DatabaseManager.shared.performBackgroundTask { (context) in
                let game = context.object(with: self.game.objectID) as! Game
                
                if let saveState = saveState
                {
                    let previewSaveState = context.object(with: saveState.objectID) as! SaveState
                    game.previewSaveState = previewSaveState
                }
                else
                {
                    game.previewSaveState = nil
                }
                
                context.saveWithErrorLogging()
            }
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func lockSaveState(_ saveState: SaveState)
    {
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait() {
            let temporarySaveState = backgroundContext.object(with: saveState.objectID) as! SaveState
            temporarySaveState.type = .locked
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    func unlockSaveState(_ saveState: SaveState)
    {
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait() {
            let temporarySaveState = backgroundContext.object(with: saveState.objectID) as! SaveState
            temporarySaveState.type = .general
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    //MARK: - Convenience Methods -
    
    func correctedSectionForSectionIndex(_ section: Int) -> Section
    {
        let sectionInfo = self.fetchedResultsController.sections![section]
        let sectionIndex = Int(sectionInfo.name)!
        
        let section = Section(rawValue: sectionIndex)!
        return section
    }
    
    func actionsForSaveState(_ saveState: SaveState) -> [Action]?
    {
        guard saveState.type != .auto else { return nil }
        
        var actions = [Action]()
        
        if self.traitCollection.forceTouchCapability == .available
        {
            if saveState.game.previewSaveState != saveState
            {
                let previewAction = Action(title: NSLocalizedString("Set as Preview Save State", comment: ""), style: .default, action: { [unowned self] action in
                    self.updatePreviewSaveState(saveState)
                })
                actions.append(previewAction)
            }
            else
            {
                let previewAction = Action(title: NSLocalizedString("Remove as Preview Save State", comment: ""), style: .default, action: { [unowned self] action in
                    self.updatePreviewSaveState(nil)
                })
                actions.append(previewAction)
            }
        }
        
        let cancelAction = Action(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, action: nil)
        actions.append(cancelAction)
        
        let renameAction = Action(title: NSLocalizedString("Rename", comment: ""), style: .default, action: { [unowned self] action in
            self.renameSaveState(saveState)
        })
        actions.append(renameAction)
        
        switch saveState.type
        {
        case .auto: break
        case .general:
            let lockAction = Action(title: NSLocalizedString("Lock", comment: ""), style: .default, action: { [unowned self] action in
                self.lockSaveState(saveState)
            })
            actions.append(lockAction)
            
        case .locked:
            let unlockAction = Action(title: NSLocalizedString("Unlock", comment: ""), style: .default, action: { [unowned self] action in
                self.unlockSaveState(saveState)
            })
            actions.append(unlockAction)
        }
        
        let deleteAction = Action(title: NSLocalizedString("Delete", comment: ""), style: .destructive, action: { [unowned self] action in
            self.deleteSaveState(saveState)
        })
        actions.append(deleteAction)
        
        return actions
    }
    
    //MARK: - Emulator -
    
    func resetEmulatorCoreIfNeeded()
    {
        // Kinda hacky, but isMovingFromParentViewController only returns yes when popping off navigation controller, and not being dismissed modally
        // Because of this, this is only run when the user returns to PauseMenuViewController, and not when they choose a save state to load
        if self.isMovingFromParentViewController
        {
            self.prepareEmulatorCore()
        }
        
        if let saveState = self.emulatorCoreSaveState
        {
            // Remove temporary save state file
            do
            {
                try FileManager.default.removeItem(at: saveState.fileURL)
            }
            catch let error as NSError
            {
                print(error)
            }
        }
    }
    
    func prepareEmulatorCore()
    {
        // We stopped emulation for 3D Touch, so now we must resume emulation and load the save state we made to make it seem like it was never stopped
        guard let emulatorCore = self.emulatorCore else { return }
        
        // Temporarily disable video rendering to prevent flickers
        emulatorCore.videoManager.isEnabled = false
        
        // Load the save state we stored a reference to
        emulatorCore.start()
        emulatorCore.pause()
        
        if let saveState = self.emulatorCoreSaveState
        {
            do
            {
                try emulatorCore.load(saveState)
            }
            catch EmulatorCore.SaveStateError.doesNotExist
            {
                print("Save State does not exist.")
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        // Re-enable video rendering
        emulatorCore.videoManager.isEnabled = true
    }
}

//MARK: - 3D Touch -
extension SaveStatesViewController: UIViewControllerPreviewingDelegate
{
    fileprivate func prepareEmulatorCoreSaveState()
    {
        guard let emulatorCore = self.emulatorCore else { return }
        
        // Store reference to current game state before we stop emulation so we can resume it if user decides to not load a save state
        
        let fileURL = FileManager.uniqueTemporaryURL()
        self.emulatorCoreSaveState = emulatorCore.saveSaveState(to: fileURL)
        
        if self.emulatorCoreSaveState != nil
        {
            emulatorCore.stop()
        }
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let indexPath = self.collectionView?.indexPathForItem(at: location),
            let layoutAttributes = self.collectionViewLayout.layoutAttributesForItem(at: indexPath)
        else { return nil }
        
        guard self.emulatorCore == nil || (self.emulatorCore != nil && self.emulatorCoreSaveState != nil) else { return nil }
        
        previewingContext.sourceRect = layoutAttributes.frame
        
        let saveState = self.fetchedResultsController.object(at: indexPath) as! SaveState
        let actions = self.actionsForSaveState(saveState)?.previewActions ?? []
        let previewImage = self.imageCache.object(forKey: saveState.imageFileURL as NSURL) ?? UIImage(contentsOfFile: saveState.imageFileURL.path)
        
        let previewGameViewController = PreviewGameViewController()
        previewGameViewController.game = self.game
        previewGameViewController.overridePreviewActionItems = actions
        previewGameViewController.previewSaveState = saveState
        previewGameViewController.previewImage = previewImage
        
        return previewGameViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        let gameViewController = viewControllerToCommit as! PreviewGameViewController        
        gameViewController.emulatorCore?.pause()
        
        let fileURL = FileManager.uniqueTemporaryURL()
        if let saveState = gameViewController.emulatorCore?.saveSaveState(to: fileURL)
        {
            gameViewController.emulatorCore?.stop()
            
            self.loadSaveState(saveState)
            
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
}

//MARK: - <UICollectionViewDataSource> -
extension SaveStatesViewController
{
    override func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        let numberOfSections = self.fetchedResultsController.sections!.count
        return numberOfSections
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let section = self.fetchedResultsController.sections![section]
        return section.numberOfObjects
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RSTGenericCellIdentifier, for: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! SaveStatesCollectionHeaderView
        self.configureCollectionViewHeaderView(headerView, forSection: (indexPath as NSIndexPath).section)
        return headerView
    }
}

//MARK: - <UICollectionViewDelegate> -
extension SaveStatesViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let saveState = self.fetchedResultsController.object(at: indexPath) as! SaveState
        
        switch self.mode
        {
        case .saving:
            
            let section = self.correctedSectionForSectionIndex((indexPath as NSIndexPath).section)
            switch section
            {
            case .auto: break
            case .general:
                let backgroundContext = DatabaseManager.shared.newBackgroundContext()
                backgroundContext.performAndWait() {
                    let temporarySaveState = backgroundContext.object(with: saveState.objectID) as! SaveState
                    self.updateSaveState(temporarySaveState)
                }
                
            case .locked:
                let alertController = UIAlertController(title: NSLocalizedString("Cannot Modify Locked Save State", comment: ""), message: NSLocalizedString("This save state must first be unlocked before it can be modified.", comment: ""), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                
            }
            
        case .loading: self.loadSaveState(saveState)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        let operation = self.imageOperationQueue[indexPath as NSCopying]
        operation?.cancel()
    }
}

//MARK: - <UICollectionViewDelegateFlowLayout> -
extension SaveStatesViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        // No need to load images from disk just to determine size, so we pass true for ignoreExpensiveOperations
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath, ignoreExpensiveOperations: true)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        self.configureCollectionViewHeaderView(self.prototypeHeader, forSection: section)
        
        let size = self.prototypeHeader.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size
    }
}

//MARK: - <NSFetchedResultsControllerDelegate> -
extension SaveStatesViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        self.collectionView?.reloadData()
        self.updateBackgroundView()
    }
}
