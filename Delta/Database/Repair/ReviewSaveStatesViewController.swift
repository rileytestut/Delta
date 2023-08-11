//
//  ReviewSaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/4/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import OSLog

import Harmony
import Roxas

extension ReviewSaveStatesViewController
{
    enum Filter
    {
        case recent
        case all
        case sinceLastBeta
    }
}

extension RecordFlags
{
    static let isGameRelationshipVerified = RecordFlags(rawValue: 1 << 0)
}

class ReviewSaveStatesViewController: UITableViewController
{
    var filter: Filter = .recent {
        didSet {
            self.updateDataSource()
        }
    }
    
    var completionHandler: (() -> Void)?
    
    private lazy var managedObjectContext = DatabaseManager.shared.newBackgroundSavingViewContext()
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var descriptionDataSource = self.makeDescriptionDataSource()
    private lazy var saveStatesDataSource = self.makeSaveStatesDataSource()
    
    private weak var _parentNavigationController: UINavigationController?
    
    init()
    {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
                
        self.dataSource.proxy = self
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ReviewSaveStatesViewController.finish))
        self.navigationItem.rightBarButtonItem = doneButton
        
        self.navigationItem.title = NSLocalizedString("Review Save States", comment: "")
        
        // Disable going back to RepairDatabaseViewController.
        self.navigationItem.setHidesBackButton(true, animated: false)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if let parent = self.parent, parent.navigationItem.title == nil
        {
            // Must change parent's navigationItem when we're contained in SwiftUI View.
            parent.navigationItem.title = NSLocalizedString("Review Save States", comment: "")
            parent.navigationItem.rightBarButtonItem = self.makeFilterButton()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        _parentNavigationController = self.parent?.navigationController
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        switch self.filter
        {
        case .all, .recent:
            if self.parent == nil || self.parent?.parent == nil
            {
                // Only finish if we're popped off navigation controller.
                self.finish()
            }
            
        case .sinceLastBeta: break
        }
    }
}

private extension ReviewSaveStatesViewController
{
    func makeDataSource() -> RSTCompositeTableViewPrefetchingDataSource<SaveState, UIImage>
    {
        let dataSource = RSTCompositeTableViewPrefetchingDataSource<SaveState, UIImage>(dataSources: [self.descriptionDataSource, self.saveStatesDataSource])
        return dataSource
    }
    
    func makeDescriptionDataSource() -> RSTDynamicTableViewPrefetchingDataSource<SaveState, UIImage>
    {
        let dataSource = RSTDynamicTableViewPrefetchingDataSource<SaveState, UIImage>()
        dataSource.numberOfSectionsHandler = { 1 }
        dataSource.numberOfItemsHandler = { _ in 0 }
        return dataSource
    }
    
    func makeSaveStatesDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<SaveState, UIImage>
    {
        let fetchedResultsController = self.makeSaveStatesFetchedResultsController()
        
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<SaveState, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.cellConfigurationHandler = { (cell, saveState, indexPath) in
            var configuration = UIListContentConfiguration.valueCell()
            configuration.prefersSideBySideTextAndSecondaryText = false
            
            let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withSymbolicTraits(.traitBold) ?? .preferredFontDescriptor(withTextStyle: .body)
            configuration.text = saveState.name ?? NSLocalizedString("Untitled", comment: "")
            configuration.textProperties.font = UIFont(descriptor: fontDescriptor, size: 0)
            
            configuration.secondaryText = SaveState.localizedDateFormatter.string(from: saveState.modifiedDate)
            configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
            
            configuration.image = nil
            configuration.imageProperties.maximumSize = CGSize(width: 80, height: 80)
            configuration.imageProperties.reservedLayoutSize = CGSize(width: 80, height: 80)
            configuration.imageProperties.cornerRadius = 6
            
            cell.contentConfiguration = configuration
            
            cell.accessoryType = .disclosureIndicator
        }
        dataSource.prefetchHandler = { (saveState, indexPath, completionHandler) in
            guard saveState.game != nil else {
                completionHandler(nil, nil)
                return nil
            }
            
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
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image, var config = cell.contentConfiguration as? UIListContentConfiguration else { return }
            config.image = image
            cell.contentConfiguration = config
        }
        
        return dataSource
    }
    
    func makeSaveStatesFetchedResultsController() -> NSFetchedResultsController<SaveState>
    {
        let fetchRequest = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.game?.name, ascending: true), NSSortDescriptor(keyPath: \SaveState.modifiedDate, ascending: false)]
        
        let predicate = NSPredicate(format: "%K != %@", #keyPath(SaveState.type), SaveStateType.auto.rawValue as NSNumber)
        
        switch self.filter
        {
        case .recent:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date().addingTimeInterval(-1 * 60 * 60 * 24 * 30)
            let recentPredicate = NSPredicate(format: "%K > %@", #keyPath(SaveState.modifiedDate), oneMonthAgo as NSDate)
            
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, recentPredicate])
            
        case .all:
            fetchRequest.predicate = predicate
            
        case .sinceLastBeta:
            let dateComponents = DateComponents(year: 2023, month: 7, day: 18, hour: 0, minute: 0, second: 0)
            let lastBetaDate = Calendar.current.date(from: dateComponents) ?? Date().addingTimeInterval(-1 * 60 * 60 * 24 * 45)
            
            let sinceLastBetaPredicate = NSPredicate(format: "%K > %@", #keyPath(SaveState.modifiedDate), lastBetaDate as NSDate)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sinceLastBetaPredicate])
        }
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: #keyPath(SaveState.game.name), cacheName: nil)
        return fetchedResultsController
    }
    
    func updateDataSource()
    {
        let fetchedResultsController = self.makeSaveStatesFetchedResultsController()
        self.saveStatesDataSource.fetchedResultsController = fetchedResultsController
    }
    
    func makeFilterButton() -> UIBarButtonItem
    {
        let recentAction = UIAction(title: NSLocalizedString("Past Month", comment: ""), image: UIImage(systemName: "calendar")) { [weak self] _ in
            self?.filter = .recent
        }
        let allAction = UIAction(title: NSLocalizedString("All Time", comment: ""), image: UIImage(systemName: "clock")) { [weak self] _ in
            self?.filter = .all
        }
        
        var options: UIMenu.Options = []
        if #available(iOS 15, *)
        {
            options = .singleSelection
            
            recentAction.state = self.filter == .recent ? .on : .off
            allAction.state = self.filter == .all ? .on : .off
        }
        
        let filterMenu = UIMenu(options: options, children: [recentAction, allAction])
        
        let filterButton = UIBarButtonItem(title: NSLocalizedString("Filter", comment: ""), image: UIImage(systemName: "calendar.badge.clock"), menu: filterMenu)
        return filterButton
    }
}

private extension ReviewSaveStatesViewController
{
    func pickGame(for saveState: SaveState)
    {
        let gamePickerViewController = GamePickerViewController()
        gamePickerViewController.gameHandler = { game in
            guard let game else { return }
            
            let previousGame = saveState.game
            if previousGame != nil
            {
                // Move files to new location.
                
                let destinationDirectory = DatabaseManager.saveStatesDirectoryURL(for: game)
                
                for fileURL in [saveState.fileURL, saveState.imageFileURL]
                {
                    guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                    
                    let destinationURL = destinationDirectory.appendingPathComponent(fileURL.lastPathComponent)
                    
                    do
                    {
                        try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true) // Copy, don't move, in case app quits before user confirms.
                    }
                    catch
                    {
                        Logger.database.error("Failed to copy SaveState “\(saveState.localizedName, privacy: .public)” from \(fileURL, privacy: .public) to \(destinationURL, privacy: .public). \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            
            let tempGame = self.managedObjectContext.object(with: game.objectID) as! Game
            saveState.game = tempGame
            
            Logger.database.debug("Re-associated SaveState “\(saveState.localizedName, privacy: .public)” with game “\(tempGame.name, privacy: .public)”. Previously: \(previousGame?.name ?? "nil", privacy: .public)")
        }
        
        self.navigationController?.pushViewController(gamePickerViewController, animated: true)
    }
    
    @objc func finish()
    {
        self.navigationItem.rightBarButtonItem?.isIndicatingActivity = true
        
        self.managedObjectContext.perform {
            do
            {
                let saveStates: [SaveState]?
                
                switch self.filter
                {
                case .recent, .all:
                    // Only upload metadata for changed SaveStates.
                    saveStates = self.managedObjectContext.updatedObjects.compactMap { $0 as? SaveState }
                    
                case .sinceLastBeta:
                    // Upload metadata for _all_ SaveStates.
                    saveStates = self.saveStatesDataSource.fetchedResultsController.fetchedObjects
                }
                
                try self.managedObjectContext.save()
                
                if let saveStates = saveStates, let coordinator = SyncManager.shared.coordinator
                {
                    let records = try coordinator.recordController.fetchRecords(for: saveStates)
                    if let context = records.first?.recordedObject?.managedObjectContext
                    {
                        try context.performAndWait {
                            for record in records
                            {
                                record.perform { managedRecord in
                                    managedRecord.flags.insert(.isGameRelationshipVerified)
                                    managedRecord.setNeedsMetadataUpdate()
                                    
                                    let saveState = record.recordedObject
                                    Logger.database.notice("Flagged SaveState “\(saveState?.localizedName ?? record.recordID.identifier, privacy: .public)” for metadata update.")
                                }
                            }
                            
                            try context.save()
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.completionHandler?()
                }
            }
            catch
            {
                DispatchQueue.main.async {
                    self.navigationItem.rightBarButtonItem?.isIndicatingActivity = false
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Save Changes", comment: ""), error: error)
                    (self._parentNavigationController ?? self).present(alertController, animated: true)
                }
            }
        }
    }
}

extension ReviewSaveStatesViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let saveState = self.dataSource.item(at: indexPath)
        self.pickGame(for: saveState)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        if section == 0
        {
            return nil
        }
        else
        {
            let section = section - 1
            
            guard let gameName = self.saveStatesDataSource.fetchedResultsController.sections?[section].name else { return NSLocalizedString("Unknown Game", comment: "") }
            return gameName
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        guard section == 0 else { return nil }
        
        return NSLocalizedString("These save states have been modified recently and may be associated with the wrong game.\n\nPlease change any incorrectly associated save states to the correct game by tapping them.", comment: "")
    }
}
