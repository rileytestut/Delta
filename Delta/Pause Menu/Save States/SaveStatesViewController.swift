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
    func saveStatesViewControllerActiveGame(saveStatesViewController: SaveStatesViewController) -> Game
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveState)
}

extension SaveStatesViewController
{
    enum Mode
    {
        case Saving
        case Loading
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
    
    private var fetchedResultsController: NSFetchedResultsController!
    
    private let imageOperationQueue = RSTOperationQueue()
    private let imageCache = NSCache()
    
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
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
        self.collectionView?.addGestureRecognizer(longPressGestureRecognizer)
        
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
        let game = self.delegate.saveStatesViewControllerActiveGame(self)
        
        let fetchRequest = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@", SaveState.Attributes.game.rawValue, game)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: SaveState.Attributes.creationDate.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
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
    
    //MARK: - Configure Cell -
    
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
    
    //MARK: - Gestures -
    
    @objc func handleLongPressGesture(gestureRecognizer: UILongPressGestureRecognizer)
    {
        guard gestureRecognizer.state == .Began else { return }
        
        guard let indexPath = self.collectionView?.indexPathForItemAtPoint(gestureRecognizer.locationInView(self.collectionView)) else { return }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete Save State", comment: ""), style: .Destructive, handler: { action in
            let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
            self.deleteSaveState(saveState)
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Save States -
    
    @IBAction func addSaveState()
    {
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlock {
            
            var game = self.delegate.saveStatesViewControllerActiveGame(self)
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
        confirmationAlertController.addAction(UIAlertAction(title: "Delete", style: .Default, handler: { action in
            
            let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
            backgroundContext.performBlock {
                let temporarySaveState = backgroundContext.objectWithID(saveState.objectID)
                backgroundContext.deleteObject(temporarySaveState)
                backgroundContext.saveWithErrorLogging()
            }
            
            
        }))
        confirmationAlertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        
        self.presentViewController(confirmationAlertController, animated: true, completion: nil)
    }
}

//MARK: - <UICollectionViewDataSource> -
extension SaveStatesViewController
{
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
}

//MARK: - <UICollectionViewDelegate> -
extension SaveStatesViewController
{
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        
        switch self.mode
        {
        case .Saving: self.updateSaveState(saveState)
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