//
//  SaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/23/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import MobileCoreServices

import DeltaCore
import MelonDSDeltaCore
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
    
    enum Sorting: String, CaseIterable
    {
        case name
        case date
        
        public var localizedName: String {
            switch self
            {
            case .name: return NSLocalizedString("Name", comment: "")
            case .date: return NSLocalizedString("Date", comment: "")
            }
        }
    }
    
    enum Filter: String, CaseIterable
    {
        case compatible
        case incompatible
        
        public var localizedName: String {
            switch self
            {
            case .compatible: return NSLocalizedString("Compatible", comment: "")
            case .incompatible: return NSLocalizedString("Incompatible", comment: "")
            }
        }
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
    
    private var preferredSorting: Sorting = UserDefaults.standard.preferredSaveStatesSorting {
        didSet {
            UserDefaults.standard.preferredSaveStatesSorting = self.preferredSorting
        }
    }
    
    private var prefersDescendingSorting: Bool = UserDefaults.standard.prefersDescendingSaveStatesSorting {
        didSet {
            UserDefaults.standard.prefersDescendingSaveStatesSorting = self.prefersDescendingSorting
        }
    }
    
    private var filter: Filter = .compatible
        
    private var vibrancyView: UIVisualEffectView!
    private var placeholderView: RSTPlaceholderView!
    
    private var prototypeCell = GridCollectionViewCell()
    private var prototypeCellWidthConstraint: NSLayoutConstraint!
    private var prototypeHeader = SaveStatesCollectionHeaderView()
    
    private var incompatibleSaveStatesCount: Int = 0
    private var incompatibleLabel: UILabel!
    private var incompatibleButton: UIButton!
    
    private weak var _previewTransitionViewController: PreviewGameViewController?
    private weak var _importingSaveState: SaveState?
    private var _exportedSaveStateURL: URL?
    
    private let dataSource: RSTFetchedResultsCollectionViewPrefetchingDataSource<SaveState, UIImage>
    
    private var emulatorCoreSaveState: SaveStateProtocol?
    
    @IBOutlet private var optionsButton: UIBarButtonItem!
    
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
            self.placeholderView.detailTextLabel.text = NSLocalizedString("Create a new save state by pressing the + button in the top right.", comment: "")
            
        case .loading:
            self.title = NSLocalizedString("Load State", comment: "")
            self.placeholderView.detailTextLabel.text = NSLocalizedString("Create a new save state by pressing the Save State option in the pause menu.", comment: "")
            self.navigationItem.rightBarButtonItems?.removeFirst()
        }
        
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: 0)
        self.prototypeCellWidthConstraint.isActive = true
        
        self.prepareEmulatorCoreSaveState()
        
        self.navigationController?.navigationBar.barStyle = .blackTranslucent
        self.navigationController?.toolbar.barStyle = .blackTranslucent
    }
    
    override func viewWillAppear(_ animated: Bool) 
    {
        super.viewWillAppear(animated)
        
        let predicate = self.makePredicate(filter: .incompatible)
        let saveStates = SaveState.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: SaveState.self)
        self.incompatibleSaveStatesCount = saveStates.count
        
        self.prepareOptionsMenu()
    }
    
    override func viewIsAppearing(_ animated: Bool) 
    {
        super.viewIsAppearing(animated)
        
        self.update()
    }
    
    override func viewDidAppear(_ animated: Bool) 
    {
        super.viewDidAppear(animated)
        
        if let core = Delta.core(for: self.game.type), core == MelonDS.core, self.incompatibleSaveStatesCount > 0, !UserDefaults.standard.showedIncompatibleDSSaveStatesAlert
        {
            let alertController = UIAlertController(title: NSLocalizedString("Incompatible Save States", comment: ""),
                                                    message: NSLocalizedString("This version of Delta is not compatible with previous Nintendo DS save states.\n\nYou can find previous save states by pressing “View Incompatible Save States” in the options menu.", comment: ""),
                                                    preferredStyle: .alert)
            alertController.addAction(.ok)
            self.present(alertController, animated: true)
            
            UserDefaults.standard.showedIncompatibleDSSaveStatesAlert = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.resetEmulatorCoreIfNeeded()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) 
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { context in
            UIView.performWithoutAnimation {
                self.update()
                self.collectionView.reloadData()
            }
        }
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
        self.placeholderView.stackView.distribution = .fill
        self.placeholderView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.placeholderView.textLabel.textColor = UIColor.white
        self.placeholderView.detailTextLabel.textColor = UIColor.white
        
        self.incompatibleLabel = UILabel()
        self.incompatibleLabel.isHidden = true
        self.incompatibleLabel.font = self.placeholderView.detailTextLabel.font
        self.incompatibleLabel.textColor = .white
        self.incompatibleLabel.numberOfLines = 0
        self.incompatibleLabel.text = NSLocalizedString("You have save states that are incompatible with this version of Delta.", comment: "")
        self.placeholderView.stackView.addArrangedSubview(self.incompatibleLabel)
        self.placeholderView.stackView.setCustomSpacing(30, after: self.placeholderView.detailTextLabel)
        self.vibrancyView.contentView.addSubview(self.placeholderView)
        
        self.incompatibleButton = UIButton(type: .system, primaryAction: UIAction(title: NSLocalizedString("View Incompatible Save States", comment: "")) { [weak self] _ in
            self?.showIncompatibleSaveStates()
        })
        self.incompatibleButton.isHidden = true
        self.incompatibleButton.translatesAutoresizingMaskIntoConstraints = false
        self.incompatibleButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        self.incompatibleButton.tintColor = .deltaPurple
        
        // Add button outside vibrancy view to ensure it retains tint color.
        let placeholderView = UIView()
        placeholderView.addSubview(self.vibrancyView, pinningEdgesWith: .zero)
        placeholderView.addSubview(incompatibleButton)
        self.dataSource.placeholderView = placeholderView
        
        NSLayoutConstraint.activate([
            self.incompatibleButton.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            self.incompatibleButton.topAnchor.constraint(equalTo: self.incompatibleLabel.bottomAnchor, constant: 15)
        ])
        
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
    
    func prepareOptionsMenu()
    {
        let sortActionsProvider: (([UIMenuElement]) -> Void) -> Void = { [weak self] completion in
            guard let self else { return completion([]) }
            
            let actions = Sorting.allCases.map { sorting in
                let state: UIMenuElement.State = (sorting == self.preferredSorting) ? .on : .off
                
                let icon: UIImage?
                if state == .on
                {
                    // Only show chevron for active sorting.
                    icon = self.prefersDescendingSorting ? UIImage(symbolNameIfAvailable: "chevron.down") : UIImage(symbolNameIfAvailable: "chevron.up")
                }
                else
                {
                    icon = nil
                }
                
                let action = UIAction(title: sorting.localizedName, image: icon, state: state) { action in
                    self.preferredSorting = sorting
                    
                    if state == .on
                    {
                        // Previously enabled, so toggle sorting direction.
                        self.prefersDescendingSorting.toggle()
                    }
                    else
                    {
                        // New, so reset sorting direction to ascending.
                        self.prefersDescendingSorting = false
                    }
                    
                    UIView.transition(with: self.collectionView, duration: 0.4, options: .transitionCrossDissolve, animations: {
                        self.updateDataSource()
                    }, completion: nil)
                }
                
                return action
            }
            
            completion(actions)
        }
        
        let filterActionsProvider: (([UIMenuElement]) -> Void) -> Void = { [weak self] completion in
            guard let self else { return completion([]) }
            
            let action: UIAction
            switch self.filter
            {
            case .compatible:
                action = UIAction(title: NSLocalizedString("View Incompatible Save States", comment: ""), image: UIImage(systemName: "x.circle")) { _ in
                    self.showIncompatibleSaveStates()
                }
                
            case .incompatible:
                action = UIAction(title: NSLocalizedString("View Compatible Save States", comment: ""), image: UIImage(systemName: "checkmark.circle")) { _ in
                    self.showCompatibleSaveStates()
                }
            }
            
            completion([action])
        }
        
        let sortActions: UIDeferredMenuElement
        let filterActions: UIDeferredMenuElement
        let menuOptions: UIMenu.Options
        
        if #available(iOS 15, *)
        {
            sortActions = UIDeferredMenuElement.uncached(sortActionsProvider)
            filterActions = UIDeferredMenuElement.uncached(filterActionsProvider)
            menuOptions = [.singleSelection, .displayInline]
        }
        else
        {
            sortActions = UIDeferredMenuElement(sortActionsProvider)
            filterActions = UIDeferredMenuElement(filterActionsProvider)
            menuOptions = [.displayInline]
        }
        
        let sortMenu = UIMenu(title: NSLocalizedString("Sort by…", comment: ""), options: menuOptions, children: [sortActions])
        var allMenus = [sortMenu]
        
        if self.incompatibleSaveStatesCount > 0
        {
            // There is at least one incompatible save state, so show the filter menu.
            let filterMenu = UIMenu(title: "", options: menuOptions, children: [filterActions])
            allMenus.append(filterMenu)
        }
        
        let optionsMenu = UIMenu(children: allMenus)
        self.optionsButton.menu = optionsMenu
    }
}

private extension SaveStatesViewController
{
    //MARK: - Update -
    func updateDataSource()
    {
        let fetchRequest: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.type), ascending: true)]
        switch self.preferredSorting
        {
        case .name:
            sortDescriptors += [NSSortDescriptor(key: #keyPath(SaveState.name), ascending: !self.prefersDescendingSorting),
                                NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: true)]
        case .date:
            sortDescriptors += [NSSortDescriptor(key: #keyPath(SaveState.creationDate), ascending: !self.prefersDescendingSorting),
                                NSSortDescriptor(key: #keyPath(SaveState.name), ascending: true)]
        }
        fetchRequest.sortDescriptors = sortDescriptors
        
        let predicate = self.makePredicate(filter: self.filter)
        fetchRequest.predicate = predicate
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(SaveState.type), cacheName: nil)
    }
    
    func makePredicate(filter: Filter) -> NSPredicate
    {
        if let system = System(gameType: self.game.type)
        {
            let predicate = NSPredicate(format: "%K == %@ AND %K == %@", #keyPath(SaveState.game), self.game, #keyPath(SaveState.coreIdentifier), system.deltaCore.identifier)
            
            if let version = system.deltaCore.version
            {
                let filterPredicate: NSPredicate
                switch filter
                {
                case .compatible: filterPredicate = NSPredicate(format: "%K == %@", #keyPath(SaveState.coreVersion), version)
                case .incompatible: filterPredicate = NSPredicate(format: "%K == nil OR %K != %@", #keyPath(SaveState.coreVersion), #keyPath(SaveState.coreVersion), version)
                }
                
                let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, filterPredicate])
                return compoundPredicate
            }
            else
            {
                // DeltaCore has no version, so fall back to showing all save states.
                return predicate
            }
        }
        else
        {
            let predicate = NSPredicate(format: "%K == %@", #keyPath(SaveState.game), self.game)
            return predicate
        }
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
            self.incompatibleLabel.textColor = .gray
            
        case .translucent:
            self.view.backgroundColor = nil
            
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark))
            
            self.placeholderView.textLabel.textColor = UIColor.white
            self.placeholderView.detailTextLabel.textColor = UIColor.white
            self.incompatibleLabel.textColor = .white
        }
        
        if self.incompatibleSaveStatesCount > 0 && self.filter == .compatible
        {
            if self.incompatibleSaveStatesCount == 1
            {
                self.incompatibleLabel.text = NSLocalizedString("You have 1 save state that is incompatible with this version of Delta.", comment: "")
            }
            else
            {
                self.incompatibleLabel.text = String(format: NSLocalizedString("You have %@ save states that are incompatible with this version of Delta.", comment: ""), NSNumber(value: self.incompatibleSaveStatesCount))
            }
            
            self.incompatibleLabel.isHidden = false
            self.incompatibleButton.isHidden = false
        }
        else
        {
            self.incompatibleLabel.isHidden = true
            self.incompatibleButton.isHidden = true
        }
                
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        
        if self.traitCollection.horizontalSizeClass == .regular
        {
            collectionViewLayout.itemWidth = 180
            collectionViewLayout.minimumInteritemSpacing = 30
        }
        else
        {
            //FIXME: Calculate actual values so resizing results in correct thumbnail size
            let averageHorizontalInset = 20.0
            
            var portraitWindowWidth = UIScreen.main.coordinateSpace.convert(UIScreen.main.bounds, to: UIScreen.main.fixedCoordinateSpace).width
            
            if let window = self.view.window
            {
                if window.bounds.height > window.bounds.width
                {
                    // Portrait window
                    portraitWindowWidth = window.bounds.width
                }
                else
                {
                    // Landscape window
                    portraitWindowWidth = window.bounds.height
                }
            }
            
            // Use dimensions that allow two cells to fill the screen horizontally with padding in portrait mode
            // We'll keep the same size for landscape orientation, which will allow more to fit
            let value = (portraitWindowWidth - (averageHorizontalInset * 3)) / 2
            collectionViewLayout.itemWidth = floor(value)
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
        confirmationAlertController.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { action in
            
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
    
    func importSaveState(_ saveState: SaveState)
    {
        self._importingSaveState = saveState
        
        let importController = ImportController(documentTypes: [kUTTypeItem as String])
        importController.delegate = self
        self.present(importController, animated: true, completion: nil)
    }
    
    func importSaveState(_ saveState: SaveState, from fileURL: URL, error: Error?)
    {
        do
        {
            if let error = error
            {
                throw error
            }
            
            try FileManager.default.copyItem(at: fileURL, to: saveState.fileURL, shouldReplace: true)
            SyncManager.shared.recordController?.updateRecord(for: saveState)
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Unable to Import Save State", comment: ""), error: error)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func exportSaveState(_ saveState: SaveState)
    {
        do
        {
            let sanitizedFilename = saveState.localizedName.components(separatedBy: .urlFilenameAllowed.inverted).joined()
            
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension("svs")
            try FileManager.default.copyItem(at: saveState.fileURL, to: temporaryURL, shouldReplace: true)
            
            self._exportedSaveStateURL = temporaryURL
            
            let documentPicker = UIDocumentPickerViewController(urls: [temporaryURL], in: .exportToService)
            documentPicker.delegate = self
            self.present(documentPicker, animated: true, completion: nil)
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Unable to Export Save State", comment: ""), error: error)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func markSaveStateAsCompatible(_ saveState: SaveState)
    {
        // Can only mark save states as compatible if the DeltaCore has an explicit version.
        guard let deltaCore = Delta.core(for: self.game.type), let version = deltaCore.version else { return }
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait() {
            let temporarySaveState = backgroundContext.object(with: saveState.objectID) as! SaveState
            temporarySaveState.coreVersion = version
            
            if temporarySaveState.type == .auto
            {
                // Move auto save states to "general" to avoid ending up with more than 2 auto save states.
                temporarySaveState.type = .general
            }
            
            backgroundContext.saveWithErrorLogging()
            
            DispatchQueue.main.async {
                self.update()
            }
        }
    }
    
    func markSaveStateAsIncompatible(_ saveState: SaveState)
    {
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait() {
            let temporarySaveState = backgroundContext.object(with: saveState.objectID) as! SaveState
            temporarySaveState.coreVersion = nil
            
            if temporarySaveState.type == .auto
            {
                // Move auto save states to "general" to avoid ending up with more than 2 auto save states.
                temporarySaveState.type = .general
            }
            
            backgroundContext.saveWithErrorLogging()
        }
    }
    
    func showCompatibleSaveStates()
    {
        UIView.transition(with: self.collectionView, duration: 0.4, options: .transitionCrossDissolve) {
            self.filter = .compatible
            self.updateDataSource()
        }
    }
    
    func showIncompatibleSaveStates()
    {
        UIView.transition(with: self.collectionView, duration: 0.4, options: .transitionCrossDissolve) {
            self.filter = .incompatible
            self.updateDataSource()
        }
    }
    
    //MARK: - Convenience Methods -
    
    func correctedSectionForSectionIndex(_ section: Int) -> Section
    {
        let sectionInfo = self.dataSource.fetchedResultsController.sections![section]
        let sectionIndex = Int(sectionInfo.name)!
        
        let section = Section(rawValue: sectionIndex)!
        return section
    }
    
    func actionsForSaveState(_ saveState: SaveState) -> [UIMenuElement]?
    {
        if self.filter != .incompatible
        {
            // Don't show actions for auto save states (unless they're incompatible).
            guard saveState.type != .auto else { return nil }
        }
        
        var actions = [UIMenuElement]()
        
        let previewAction: UIAction
        if saveState.game?.previewSaveState != saveState
        {
            previewAction = UIAction(title: NSLocalizedString("Set as Preview Save State", comment: ""), image: UIImage(symbolNameIfAvailable: "eye.fill")) { [unowned self] action in
                self.updatePreviewSaveState(saveState)
            }
        }
        else
        {
            previewAction = UIAction(title: NSLocalizedString("Remove as Preview Save State", comment: ""), image: UIImage(symbolNameIfAvailable: "eye.slash.fill")) { [unowned self] action in
                self.updatePreviewSaveState(nil)
            }
        }
        
        let previewMenu = UIMenu(options: .displayInline, children: [previewAction])
        
        let markCompatibleAction = UIAction(title: NSLocalizedString("Mark as Compatible", comment: ""), image: UIImage(symbolNameIfAvailable: "checkmark.circle")) { [unowned self] _ in
            self.markSaveStateAsCompatible(saveState)
        }
        
        let markIncompatibleAction = UIAction(title: NSLocalizedString("Mark as Incompatible", comment: ""), image: UIImage(symbolNameIfAvailable: "x.circle")) { [unowned self] _ in
            self.markSaveStateAsIncompatible(saveState)
        }
        
        let compatibilityMenu = UIMenu(options: .displayInline, children: [markCompatibleAction])
        let incompatibilityMenu = UIMenu(options: .displayInline, children: [markIncompatibleAction])
        
        
        switch self.filter
        {
        case .compatible: 
            actions.append(previewMenu)
            actions.append(incompatibilityMenu)
        case .incompatible: actions.append(compatibilityMenu)
        }
        
        let renameAction = UIAction(title: NSLocalizedString("Rename", comment: ""), image: UIImage(symbolNameIfAvailable: "pencil")) { [unowned self] action in
            self.renameSaveState(saveState)
        }
        actions.append(renameAction)
        
        switch saveState.type
        {
        case .auto: break
        case .quick: break
        case .general:
            let lockAction = UIAction(title: NSLocalizedString("Lock", comment: ""), image: UIImage(symbolNameIfAvailable: "lock.fill")) { [unowned self] action in
                self.lockSaveState(saveState)
            }
            actions.append(lockAction)
            
        case .locked:
            let unlockAction = UIAction(title: NSLocalizedString("Unlock", comment: ""), image: UIImage(symbolNameIfAvailable: "lock.open.fill")) { [unowned self] action in
                self.unlockSaveState(saveState)
            }
            actions.append(unlockAction)
        }
        
        let importAction = UIAction(title: NSLocalizedString("Import", comment: ""), image: UIImage(symbolNameIfAvailable: "square.and.arrow.down")) { [unowned self] action in
            self.importSaveState(saveState)
        }
        
        let exportAction = UIAction(title: NSLocalizedString("Export", comment: ""), image: UIImage(symbolNameIfAvailable: "square.and.arrow.up")) { [unowned self] action in
            self.exportSaveState(saveState)
        }
        
        let manageMenu = UIMenu(options: .displayInline, children: [importAction, exportAction])
        actions.append(manageMenu)
        
        let deleteAction = UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(symbolNameIfAvailable: "trash"), attributes: .destructive) { [unowned self] action in
            self.deleteSaveState(saveState)
        }
        
        let deleteMenu = UIMenu(options: .displayInline, children: [deleteAction])
        actions.append(deleteMenu)
        
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
        
        switch self.filter
        {
        case .incompatible:
            let alertController = UIAlertController(title: NSLocalizedString("Incompatible Save State", comment: ""), message: NSLocalizedString("This save state is incompatible with this version of Delta.", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
        case .compatible:
            
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
            guard let self = self, Settings.isPreviewsEnabled, self.filter != .incompatible else { return nil }
            
            let previewGameViewController = self.makePreviewGameViewController(for: saveState)
            self._previewTransitionViewController = previewGameViewController
            
            return previewGameViewController
        }) { suggestedActions in
            return UIMenu(title: saveState.localizedName, children: actions)
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

//MARK: - <ImportControllerDelegate> -
extension SaveStatesViewController: ImportControllerDelegate
{
    func importController(_ importController: ImportController, didImportItemsAt urls: Set<URL>, errors: [Error])
    {
        if let saveState = self._importingSaveState, let fileURL = urls.first
        {
            self.importSaveState(saveState, from: fileURL, error: errors.first)
        }
        
        self._importingSaveState = nil
    }
    
    func importControllerDidCancel(_ importController: ImportController)
    {
        self.presentedViewController?.dismiss(animated: true, completion: nil)
    }
}

//MARK: - <UIDocumentPickerDelegate> -
extension SaveStatesViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        if let saveStateURL = self._exportedSaveStateURL
        {
            try? FileManager.default.removeItem(at: saveStateURL)
        }
        
        self._exportedSaveStateURL = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        if let saveStateURL = self._exportedSaveStateURL
        {
            try? FileManager.default.removeItem(at: saveStateURL)
        }
        
        self._exportedSaveStateURL = nil
    }
}

private extension UserDefaults
{
    @NSManaged var showedIncompatibleDSSaveStatesAlert: Bool
    @NSManaged var prefersDescendingSaveStatesSorting: Bool
    
    @nonobjc var preferredSaveStatesSorting: SaveStatesViewController.Sorting {
        get {
            let sorting = _preferredSaveStatesSorting.flatMap { SaveStatesViewController.Sorting(rawValue: $0) } ?? .date
            return sorting
        }
        set {
            _preferredSaveStatesSorting = newValue.rawValue
        }
    }
    @NSManaged @objc(preferredSaveStatesSorting) private var _preferredSaveStatesSorting: String?
}
