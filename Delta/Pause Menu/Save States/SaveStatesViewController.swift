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
    func saveStatesViewControllerActiveEmulatorCore(saveStatesViewController: SaveStatesViewController) -> EmulatorCore
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveStateType)
}

extension SaveStatesViewController
{
    enum Mode
    {
        case Saving
        case Loading
    }
    
    enum Section: Int
    {
        case Auto
        case General
        case Locked
    }
}

class SaveStatesViewController: UICollectionViewController
{
    weak var delegate: SaveStatesViewControllerDelegate! {
        didSet {
            self.updateFetchedResultsController()
        }
    }
    
    var mode = Mode.Saving
    
    private var backgroundView: RSTBackgroundView!
    
    private var prototypeCell = GridCollectionViewCell()
    private var prototypeCellWidthConstraint: NSLayoutConstraint!
    private var prototypeHeader = SaveStatesCollectionHeaderView()
    
    private var fetchedResultsController: NSFetchedResultsController!
    
    private let imageOperationQueue = RSTOperationQueue()
    private let imageCache = NSCache()
    
    private var currentGameState: SaveStateType?
    
    private let dateFormatter: NSDateFormatter
    
    required init?(coder aDecoder: NSCoder)
    {
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.timeStyle = .ShortStyle
        self.dateFormatter.dateStyle = .ShortStyle
        
        super.init(coder: aDecoder)
    }
}

extension SaveStatesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.hidden = true
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.whiteColor()
        self.backgroundView.detailTextLabel.textColor = UIColor.whiteColor()
        self.view.insertSubview(self.backgroundView, atIndex: 0)
        
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        let averageHorizontalInset = (collectionViewLayout.sectionInset.left + collectionViewLayout.sectionInset.right) / 2
        let portraitScreenWidth = UIScreen.mainScreen().coordinateSpace.convertRect(UIScreen.mainScreen().bounds, toCoordinateSpace: UIScreen.mainScreen().fixedCoordinateSpace).width
        
        // Use dimensions that allow two cells to fill the screen horizontally with padding in portrait mode
        // We'll keep the same size for landscape orientation, which will allow more to fit
        collectionViewLayout.itemWidth = (portraitScreenWidth - (averageHorizontalInset * 3)) / 2
        
        switch self.mode
        {
        case .Saving:
            self.title = NSLocalizedString("Save State", comment: "")
            self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
            
        case .Loading:
            self.title = NSLocalizedString("Load State", comment: "")
            self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the Save State option in the pause menu.", comment: "")
            self.navigationItem.rightBarButtonItem = nil
        }
        
        // Manually update prototype cell properties
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(collectionViewLayout.itemWidth)
        self.prototypeCellWidthConstraint.active = true
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SaveStatesViewController.handleLongPressGesture(_:)))
        self.collectionView?.addGestureRecognizer(longPressGestureRecognizer)
        
        self.registerForPreviewingWithDelegate(self, sourceView: self.collectionView!)
        
        self.updateBackgroundView()
    }
    
    override func viewWillAppear(animated: Bool)
    {
        if self.fetchedResultsController.fetchedObjects == nil
        {
            do
            {
                try self.fetchedResultsController.performFetch()
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        self.updateBackgroundView()
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(animated: Bool)
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
        let game = self.delegate.saveStatesViewControllerActiveEmulatorCore(self).game as! Game
        
        let fetchRequest = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SaveState.Attributes.game.rawValue, game)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: SaveState.Attributes.type.rawValue, ascending: true), NSSortDescriptor(key: SaveState.Attributes.creationDate.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: SaveState.Attributes.type.rawValue, cacheName: nil)
        self.fetchedResultsController.delegate = self
    }
    
    func updateBackgroundView()
    {
        if let fetchedObjects = self.fetchedResultsController.fetchedObjects where fetchedObjects.count > 0
        {
            self.backgroundView.hidden = true
        }
        else
        {
            self.backgroundView.hidden = false
        }
    }
    
    //MARK: - Configure Views -
    
    func configureCollectionViewCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath, ignoreExpensiveOperations ignoreOperations: Bool = false)
    {
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        
        cell.imageView.backgroundColor = UIColor.whiteColor()
        cell.imageView.image = UIImage(named: "DeltaPlaceholder")
        
        if !ignoreOperations
        {
            let imageOperation = LoadImageOperation(URL: saveState.imageFileURL)
            imageOperation.imageCache = self.imageCache
            imageOperation.completionHandler = { image in
                
                if let image = image
                {
                    cell.imageView.backgroundColor = nil
                    cell.imageView.image = image
                }
            }
            
            // Ensure initially visible cells have loaded their image before they appear to prevent potential flickering from placeholder to thumbnail
            if self.appearing
            {
                imageOperation.immediate = true
            }
            
            self.imageOperationQueue.addOperation(imageOperation, forKey: indexPath)
        }        
        
        cell.maximumImageSize = CGSizeMake(self.prototypeCellWidthConstraint.constant, (self.prototypeCellWidthConstraint.constant / 8.0) * 7.0)
        
        cell.textLabel.textColor = UIColor.whiteColor()
        cell.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        let name = saveState.name ?? self.dateFormatter.stringFromDate(saveState.modifiedDate)
        cell.textLabel.text = name
    }
    
    func configureCollectionViewHeaderView(headerView: SaveStatesCollectionHeaderView, forSection section: Int)
    {
        let section = self.correctedSectionForSectionIndex(section)
        
        let title: String
        
        switch section
        {
        case .Auto: title = NSLocalizedString("Auto Save", comment: "")
        case .General: title = NSLocalizedString("General", comment: "")
        case .Locked: title = NSLocalizedString("Locked", comment: "")
        }
        
        headerView.textLabel.text = title
    }
    
    //MARK: - Gestures -
    
    @objc func handleLongPressGesture(gestureRecognizer: UILongPressGestureRecognizer)
    {
        guard gestureRecognizer.state == .Began else { return }
        
        guard let indexPath = self.collectionView?.indexPathForItemAtPoint(gestureRecognizer.locationInView(self.collectionView)) else { return }
        
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete Save State", comment: ""), style: .Destructive, handler: { action in
            self.deleteSaveState(saveState)
        }))
        
        let section = self.correctedSectionForSectionIndex(indexPath.section)
        switch section
        {
        case .Auto: break
        case .General:
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Lock Save State", comment: ""), style: .Default, handler: { action in
                self.lockSaveState(saveState)
            }))
            
        case .Locked:
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Unlock Save State", comment: ""), style: .Default, handler: { action in
                self.unlockSaveState(saveState)
            }))
            
        }
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Save States -
    
    @IBAction func addSaveState()
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlock {
            
            var game = self.delegate.saveStatesViewControllerActiveEmulatorCore(self).game as! Game
            game = backgroundContext.objectWithID(game.objectID) as! Game
            
            let saveState = SaveState.insertIntoManagedObjectContext(backgroundContext)
            saveState.game = game
            
            self.updateSaveState(saveState)
        }
    }
    
    func updateSaveState(saveState: SaveState)
    {
        self.delegate?.saveStatesViewController(self, updateSaveState: saveState)
        saveState.managedObjectContext?.saveWithErrorLogging()
    }
    
    func loadSaveState(saveState: SaveState)
    {
        self.delegate?.saveStatesViewController(self, loadSaveState: saveState)
    }
    
    func deleteSaveState(saveState: SaveState)
    {
        let confirmationAlertController = UIAlertController(title: NSLocalizedString("Confirm Deletion", comment: ""), message: NSLocalizedString("Are you sure you want to delete this save state? This cannot be undone.", comment: ""), preferredStyle: .Alert)
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .Default, handler: { action in
            
            let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
            backgroundContext.performBlock {
                let temporarySaveState = backgroundContext.objectWithID(saveState.objectID)
                backgroundContext.deleteObject(temporarySaveState)
                backgroundContext.saveWithErrorLogging()
            }
            
            
        }))
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        
        self.presentViewController(confirmationAlertController, animated: true, completion: nil)
    }
    
    func lockSaveState(saveState: SaveState)
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlockAndWait() {
            let temporarySaveState = backgroundContext.objectWithID(saveState.objectID) as! SaveState
            temporarySaveState.type = .Locked
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    func unlockSaveState(saveState: SaveState)
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlockAndWait() {
            let temporarySaveState = backgroundContext.objectWithID(saveState.objectID) as! SaveState
            temporarySaveState.type = .General
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    //MARK: - Emulator -
    
    func resetEmulatorCoreIfNeeded()
    {
        // Kinda hacky, but isMovingFromParentViewController only returns yes when popping off navigation controller, and not being dismissed modally
        // Because of this, this is only run when the user returns to PauseMenuViewController, and not when they choose a save state to load
        guard let saveState = self.currentGameState where self.isMovingFromParentViewController() else { return }
        
        // We stopped emulation for 3D Touch, so now we must resume emulation and load the save state we made to make it seem like it was never stopped
        let emulatorCore = self.delegate.saveStatesViewControllerActiveEmulatorCore(self)
        
        // Temporarily disable video rendering to prevent flickers
        emulatorCore.videoManager.enabled = false
        
        // Load the save state we stored a reference to
        emulatorCore.startEmulation()
        emulatorCore.pauseEmulation()
        emulatorCore.loadSaveState(saveState)
        
        // Re-enable video rendering
        emulatorCore.videoManager.enabled = true
        
        // Remove temporary save state file
        do
        {
            try NSFileManager.defaultManager().removeItemAtURL(saveState.fileURL)
        }
        catch let error as NSError
        {
            print(error)
        }
    }
    
    //MARK: - Convenience Methods -
    
    func correctedSectionForSectionIndex(section: Int) -> Section
    {
        let sectionInfo = self.fetchedResultsController.sections![section]
        let sectionIndex = Int(sectionInfo.name)!
        
        let section = Section(rawValue: sectionIndex)!
        return section
    }
}

//MARK: - <UIViewControllerPreviewingDelegate> -
extension SaveStatesViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let indexPath = self.collectionView?.indexPathForItemAtPoint(location), layoutAttributes = self.collectionViewLayout.layoutAttributesForItemAtIndexPath(indexPath) else { return nil }
        
        previewingContext.sourceRect = layoutAttributes.frame
        
        let emulatorCore = self.delegate.saveStatesViewControllerActiveEmulatorCore(self)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        let emulationViewController = storyboard.instantiateViewControllerWithIdentifier("emulationViewController") as! EmulationViewController
        emulationViewController.game = emulatorCore.game as! Game
        emulationViewController.overridePreviewActionItems = []
        emulationViewController.deferredPreparationHandler = { [unowned emulationViewController] in
            
            // Store reference to current game state before we stop emulation so we can resume it if user decides to not load a save state
            if self.currentGameState == nil
            {
                emulatorCore.saveSaveState() { saveState in
                    
                    let fileURL = NSFileManager.uniqueTemporaryURL()
                    
                    do
                    {
                        try NSFileManager.defaultManager().moveItemAtURL(saveState.fileURL, toURL: fileURL)
                    }
                    catch let error as NSError
                    {
                        print(error)
                    }
                    
                    self.currentGameState = DeltaCore.SaveState(name: nil, fileURL: fileURL)
                }
            }
            
            emulatorCore.stopEmulation()
            
            
            let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
            
            emulationViewController.emulatorCore.startEmulation()
            emulationViewController.emulatorCore.pauseEmulation()
            emulationViewController.emulatorCore.loadSaveState(saveState)
        }
        
        return emulationViewController
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController)
    {
        let emulationViewController = viewControllerToCommit as! EmulationViewController
        
        emulationViewController.emulatorCore.pauseEmulation()
        emulationViewController.emulatorCore.saveSaveState() { saveState in
            
            emulationViewController.emulatorCore.stopEmulation()
            
            let emulatorCore = self.delegate.saveStatesViewControllerActiveEmulatorCore(self)
            
            emulatorCore.audioManager.stop()
            
            emulatorCore.startEmulation()
            emulatorCore.pauseEmulation()
            
            self.delegate.saveStatesViewController(self, loadSaveState: saveState)
            
            emulatorCore.videoManager.enabled = true
        }
    }
}

//MARK: - <UICollectionViewDataSource> -
extension SaveStatesViewController
{
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int
    {
        let numberOfSections = self.fetchedResultsController.sections!.count
        return numberOfSections
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let section = self.fetchedResultsController.sections![section]
        return section.numberOfObjects
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(RSTGenericCellIdentifier, forIndexPath: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView
    {
        let headerView = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "Header", forIndexPath: indexPath) as! SaveStatesCollectionHeaderView
        self.configureCollectionViewHeaderView(headerView, forSection: indexPath.section)
        return headerView
    }
}

//MARK: - <UICollectionViewDelegate> -
extension SaveStatesViewController
{
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        
        switch self.mode
        {
        case .Saving:
            
            let section = self.correctedSectionForSectionIndex(indexPath.section)
            switch section
            {
            case .Auto: break
            case .General:
                let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
                backgroundContext.performBlockAndWait() {
                    let temporarySaveState = backgroundContext.objectWithID(saveState.objectID) as! SaveState
                    self.updateSaveState(temporarySaveState)
                }
                
            case .Locked:
                let alertController = UIAlertController(title: NSLocalizedString("Cannot Modify Locked Save State", comment: ""), message: NSLocalizedString("This save state must first be unlocked before it can be modified.", comment: ""), preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .Cancel, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
                
            }
            
        case .Loading: self.loadSaveState(saveState)
        }
    }
    
    override func collectionView(collectionView: UICollectionView, didEndDisplayingCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath)
    {
        let operation = self.imageOperationQueue.operationForKey(indexPath)
        operation?.cancel()
    }
}

//MARK: - <UICollectionViewDelegateFlowLayout> -
extension SaveStatesViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        // No need to load images from disk just to determine size, so we pass true for ignoreExpensiveOperations
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath, ignoreExpensiveOperations: true)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        self.configureCollectionViewHeaderView(self.prototypeHeader, forSection: section)
        
        let size = self.prototypeHeader.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}

//MARK: - <NSFetchedResultsControllerDelegate> -
extension SaveStatesViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.collectionView?.reloadData()
        self.updateBackgroundView()
    }
}