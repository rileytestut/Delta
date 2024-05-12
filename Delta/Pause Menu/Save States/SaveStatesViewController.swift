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
        case quick
        case general
        case locked
    }
}

class SaveStatesViewController: UICollectionViewController
{
    var game: Game! {
        didSet {
            self.updateDataSource()
        }
    }
    
    // Reference to a current EmulatorCore. emulatorCore.game does _not_ have to match self.game
    var emulatorCore: EmulatorCore?
    
    weak var delegate: SaveStatesViewControllerDelegate?
    
    var mode = Mode.loading
    
    var theme = Theme.translucent {
        didSet {
            if self.isViewLoaded
            {
                self.update()
            }
        }
    }
        
    private var vibrancyView: UIVisualEffectView!
    private var placeholderView: RSTPlaceholderView!
    
    private var prototypeCell = GridCollectionViewCell()
    private var prototypeCellWidthConstraint: NSLayoutConstraint!
    private var prototypeHeader = SaveStatesCollectionHeaderView()
    
    private weak var _previewTransitionViewController: PreviewGameViewController?
    
    private let dataSource: RSTFetchedResultsCollectionViewPrefetchingDataSource<SaveState, UIImage>
    
    private var emulatorCoreSaveState: SaveStateProtocol?
    
    @IBOutlet private var sortButton: UIButton!
    
    required init?(coder aDecoder: NSCoder)
    {
        self.dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<SaveState, UIImage>(fetchedResultsController: NSFetchedResultsController())
        
        super.init(coder: aDecoder)
        
        self.prepareDataSource()
    }
}

extension SaveStatesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.prefetchDataSource = self.dataSource
        
        switch self.mode
        {
        case .saving:
            self.title = NSLocalizedString("Save State", comment: "")
            self.placeholderView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
            
        case .loading:
            self.title = NSLocalizedString("Load State", comment: "")
            self.placeholderView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the Save State option in the pause menu.", comment: "")
            self.navigationItem.rightBarButtonItems?.removeFirst()
        }
        
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: 0)
        self.prototypeCellWidthConstraint.isActive = true
        
        self.prepareEmulatorCoreSaveState()
        
        if #available(iOS 13, *) {}
        else
        {
            self.registerForPreviewing(with: self, sourceView: self.collectionView!)
            
            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(SaveStatesViewController.handleLongPressGesture(_:)))
            self.collectionView?.addGestureRecognizer(longPressGestureRecognizer)
        }
        
        self.navigationController?.navigationBar.barStyle = .blackTranslucent
        self.navigationController?.toolbar.barStyle = .blackTranslucent
        
        self.update()
    }    
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.resetEmulatorCoreIfNeeded()
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

private extension SaveStatesViewController
{
    func prepareDataSource()
    {
        self.dataSource.proxy = self
        
        self.vibrancyView = UIVisualEffectView(effect: nil)
        
        self.placeholderView = RSTPlaceholderView(frame: CGRect(x: 0, y: 0, width: self.vibrancyView.bounds.width, height: self.vibrancyView.bounds.height))
        self.placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.placeholderView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.placeholderView.textLabel.textColor = UIColor.white
        self.placeholderView.detailTextLabel.textColor = UIColor.white
        self.vibrancyView.contentView.addSubview(self.placeholderView)
        
        self.dataSource.placeholderView = self.vibrancyView
        
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, item, indexPath) in
            self.configure(cell as! GridCollectionViewCell, for: indexPath)
        }
        
        self.dataSource.prefetchHandler = { [unowned self] (saveState, indexPath, completionHandler) in
            let imageOperation = LoadImageURLOperation(url: saveState.imageFileURL)
            imageOperation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
                        
            if self.isAppearing
            {
                imageOperation.start()
                imageOperation.waitUntilFinished()
                return nil
            }
            
            return imageOperation
        }
        
        self.dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image, let cell = cell as? GridCollectionViewCell else { return }
            
            cell.imageView.backgroundColor = nil
            cell.imageView.image = image
            
            cell.isImageViewVibrancyEnabled = false
        }
    }
}

private extension SaveStatesViewController
{
    //MARK: - Update -
    func updateDataSource()
    {
        let fetchRequest: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.type), ascending: true), NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: Settings.sortSaveStatesByOldestFirst)]
        
        if let system = System(gameType: self.game.type)
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(SaveState.game), self.game, #keyPath(SaveState.coreIdentifier), system.deltaCore.identifier)
        }
        else
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(SaveState.game), self.game)
        }
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(SaveState.type), cacheName: nil)
    }
    
    func update()
    {
        switch self.theme
        {
        case .opaque:
            self.view.backgroundColor = UIColor.deltaDarkGray
            
            self.vibrancyView.effect = nil
            
            self.placeholderView.textLabel.textColor = UIColor.gray
            self.placeholderView.detailTextLabel.textColor = UIColor.gray
            
        case .translucent:
            self.view.backgroundColor = nil
            
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark))
            
            self.placeholderView.textLabel.textColor = UIColor.white
            self.placeholderView.detailTextLabel.textColor = UIColor.white
        }
        
        self.sortButton.transform = CGAffineTransform.identity.rotated(by: Settings.sortSaveStatesByOldestFirst ? 0 : .pi)
        
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        
        if self.traitCollection.horizontalSizeClass == .regular
        {
            collectionViewLayout.itemWidth = 180
            collectionViewLayout.minimumInteritemSpacing = 30
        }
        else
        {
            let averageHorizontalInset = (collectionViewLayout.sectionInset.left + collectionViewLayout.sectionInset.right) / 2
            let portraitScreenWidth = UIScreen.main.coordinateSpace.convert(UIScreen.main.bounds, to: UIScreen.main.fixedCoordinateSpace).width
            
            // Use dimensions that allow two cells to fill the screen horizontally with padding in portrait mode
            // We'll keep the same size for landscape orientation, which will allow more to fit
            collectionViewLayout.itemWidth = floor((portraitScreenWidth - (averageHorizontalInset * 3)) / 2)
        }
        
        // Manually update prototype cell properties
        self.prototypeCellWidthConstraint.constant = collectionViewLayout.itemWidth
    }
    
    //MARK: - Configure Views -
    
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath)
    {
        let saveState = self.dataSource.item(at: indexPath)
        
        cell.imageView.backgroundColor = UIColor.white
        cell.imageView.image = UIImage(named: "DeltaPlaceholder")
        cell.textLabel.textColor = UIColor.gray
        
        switch self.theme
        {
        case .opaque:
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
        case .translucent:
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
        }        
        
        let deltaCore = Delta.core(for: self.game.type)!
        
        let dimensions = deltaCore.videoFormat.dimensions
        cell.maximumImageSize = CGSize(width: self.prototypeCellWidthConstraint.constant, height: (self.prototypeCellWidthConstraint.constant / dimensions.width) * dimensions.height)
        
        cell.textLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        cell.textLabel.text = saveState.localizedName
    }
    
    func configure(_ headerView: SaveStatesCollectionHeaderView, forSection section: Int)
    {
        let section = self.correctedSectionForSectionIndex(section)
        
        let title: String
        
        switch section
        {
        case .auto: title = NSLocalizedString("Auto Save", comment: "")
        case .quick: title = NSLocalizedString("Quick Save", comment: "")
        case .general: title = NSLocalizedString("General", comment: "")
        case .locked: title = NSLocalizedString("Locked", comment: "")
        }
        
        headerView.textLabel.text = title
        
        switch self.theme
        {
        case .opaque:
            headerView.textLabel.textColor = UIColor.lightGray
            headerView.isTextLabelVibrancyEnabled = false
            
        case .translucent:
            headerView.textLabel.textColor = UIColor.white
            headerView.isTextLabelVibrancyEnabled = true
        }
    }
    
    //MARK: - Gestures -
    
    @objc func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer)
    {
        guard gestureRecognizer.state == .began else { return }
        
        guard let indexPath = self.collectionView?.indexPathForItem(at: gestureRecognizer.location(in: self.collectionView)) else { return }
        
        let saveState = self.dataSource.item(at: indexPath)
        
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
            saveState.type = .general
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
        let alertController = UIAlertController(title: NSLocalizedString("Rename Save State", comment: ""), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.text = saveState.name
            textField.placeholder = NSLocalizedString("Name", comment: "")
            textField.autocapitalizationType = .words
            textField.returnKeyType = .done
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default, handler: { [unowned alertController] (action) in
            self.rename(saveState, with: alertController.textFields?.first?.text)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func rename(_ saveState: SaveState, with name: String?)
    {
        var name = name
        if (name ?? "").count == 0
        {
            // When text is nil, we know to show the timestamp instead
            name = nil
        }
        
        DatabaseManager.shared.performBackgroundTask { (context) in
            let saveState = context.object(with: saveState.objectID) as! SaveState
            saveState.name = name
            
            context.saveWithErrorLogging()
        }
    }
    
    func updatePreviewSaveState(_ saveState: SaveState?)
    {
        let message: String
        
        if #available(iOS 13, *)
        {
            message = NSLocalizedString("The Preview Save State is loaded whenever you long press this game from the Main Menu. Are you sure you want to change it?", comment: "")
        }
        else
        {
            message = NSLocalizedString("The Preview Save State is loaded whenever you 3D Touch this game from the Main Menu. Are you sure you want to change it?", comment: "")
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Change Preview Save State?", comment: ""), message: message, preferredStyle: .alert)
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
    
    @IBAction func changeSortOrder(_ sender: UIButton)
    {
        Settings.sortSaveStatesByOldestFirst.toggle()
            
        UIView.transition(with: self.collectionView, duration: 0.4, options: .transitionCrossDissolve, animations: {
            self.updateDataSource()
        }, completion: nil)
        
        UIView.animate(withDuration: 0.4) {
            self.update()
        }
        
        let toastView = RSTToastView()
        toastView.textLabel.text = Settings.sortSaveStatesByOldestFirst ? NSLocalizedString("Oldest First", comment: "") : NSLocalizedString("Newest First", comment: "")
        toastView.presentationEdge = .top
        toastView.tintColor = UIColor.deltaPurple
        toastView.show(in: self.view, duration: 2.0)
    }
    
    //MARK: - Convenience Methods -
    
    func correctedSectionForSectionIndex(_ section: Int) -> Section
    {
        let sectionInfo = self.dataSource.fetchedResultsController.sections![section]
        let sectionIndex = Int(sectionInfo.name)!
        
        let section = Section(rawValue: sectionIndex)!
        return section
    }
    
    func actionsForSaveState(_ saveState: SaveState) -> [Action]?
    {
        guard saveState.type != .auto else { return nil }
        
        let isPreviewAvailable: Bool
        
        if #available(iOS 13, *)
        {
            isPreviewAvailable = true
        }
        else
        {
            isPreviewAvailable = (self.traitCollection.forceTouchCapability == .available)
        }
        
        var actions = [Action]()
        
        if isPreviewAvailable
        {
            if saveState.game?.previewSaveState != saveState
            {
                let previewAction = Action(title: NSLocalizedString("Set as Preview Save State", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "eye.fill"), action: { [unowned self] action in
                    self.updatePreviewSaveState(saveState)
                })
                actions.append(previewAction)
            }
            else
            {
                let previewAction = Action(title: NSLocalizedString("Remove as Preview Save State", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "eye.slash.fill"), action: { [unowned self] action in
                    self.updatePreviewSaveState(nil)
                })
                actions.append(previewAction)
            }
        }
        
        let cancelAction = Action(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, action: nil)
        actions.append(cancelAction)
        
        let renameAction = Action(title: NSLocalizedString("Rename", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "pencil.and.ellipsis.rectangle"), action: { [unowned self] action in
            self.renameSaveState(saveState)
        })
        actions.append(renameAction)
        
        switch saveState.type
        {
        case .auto: break
        case .quick: break
        case .general:
            let lockAction = Action(title: NSLocalizedString("Lock", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "lock.fill"), action: { [unowned self] action in
                self.lockSaveState(saveState)
            })
            actions.append(lockAction)
            
        case .locked:
            let unlockAction = Action(title: NSLocalizedString("Unlock", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "lock.open.fill"), action: { [unowned self] action in
                self.unlockSaveState(saveState)
            })
            actions.append(unlockAction)
        }
        
        let deleteAction = Action(title: NSLocalizedString("Delete", comment: ""), style: .destructive, image: UIImage(symbolNameIfAvailable: "trash"), action: { [unowned self] action in
            self.deleteSaveState(saveState)
        })
        actions.append(deleteAction)
        
        return actions
    }
    
    //MARK: - Emulator -
    
    func resetEmulatorCoreIfNeeded()
    {
        self.prepareEmulatorCore()
        
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
        // Additionally, if emulatorCore.state != .stopped, then we have already resumed emulation with correct save state, and don't need to do it again
        guard let emulatorCore = self.emulatorCore, emulatorCore.state == .stopped else { return }
        
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
    private func prepareEmulatorCoreSaveState()
    {
        guard let emulatorCore = self.emulatorCore else { return }
        
        // Store reference to current game state before we stop emulation so we can resume it if user decides to not load a save state
        
        let fileURL = FileManager.default.uniqueTemporaryURL()
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
        
        let saveState = self.dataSource.item(at: indexPath)
        
        let previewGameViewController = self.makePreviewGameViewController(for: saveState)
        _previewTransitionViewController = previewGameViewController
        
        return previewGameViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        self.commitPreviewTransition()
    }
    
    func makePreviewGameViewController(for saveState: SaveState) -> PreviewGameViewController
    {
        let previewImage = self.dataSource.prefetchItemCache.object(forKey: saveState) ?? UIImage(contentsOfFile: saveState.imageFileURL.path)
        
        let gameViewController = PreviewGameViewController()
        gameViewController.game = self.game
        gameViewController.previewSaveState = saveState
        gameViewController.previewImage = previewImage
        
        let actions = self.actionsForSaveState(saveState)?.previewActions ?? []
        gameViewController.overridePreviewActionItems = actions
        
        return gameViewController
    }
    
    func commitPreviewTransition()
    {
        guard let gameViewController = self._previewTransitionViewController else { return }
        gameViewController.pauseEmulation()
        
        let fileURL = FileManager.default.uniqueTemporaryURL()
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
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! SaveStatesCollectionHeaderView
        self.configure(headerView, forSection: indexPath.section)
        return headerView
    }
}

//MARK: - <UICollectionViewDelegate> -
extension SaveStatesViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let saveState = self.dataSource.item(at: indexPath)
        
        switch self.mode
        {
        case .saving:
            
            let section = self.correctedSectionForSectionIndex(indexPath.section)
            switch section
            {
            case .auto: break
            case .quick, .general:
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
}

//MARK: - <UICollectionViewDelegateFlowLayout> -
extension SaveStatesViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        self.configure(self.prototypeCell, for: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        self.configure(self.prototypeHeader, forSection: section)
        
        let size = self.prototypeHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size
    }
}

@available(iOS 13.0, *)
extension SaveStatesViewController
{
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let saveState = self.dataSource.item(at: indexPath)
        guard let actions = self.actionsForSaveState(saveState) else { return nil }
        
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: { [weak self] in
            guard let self = self, Settings.isPreviewsEnabled else { return nil }
            
            let previewGameViewController = self.makePreviewGameViewController(for: saveState)
            self._previewTransitionViewController = previewGameViewController
            
            return previewGameViewController
        }) { suggestedActions in
            return UIMenu(title: saveState.localizedName, children: actions.menuActions)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating)
    {
        self.commitPreviewTransition()
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        guard let indexPath = configuration.identifier as? NSIndexPath else { return nil }
        guard let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? GridCollectionViewCell else { return nil }
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear

        let preview = UITargetedPreview(view: cell.imageView, parameters: parameters)
        return preview
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        self._previewTransitionViewController = nil
        return self.collectionView(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }
}
