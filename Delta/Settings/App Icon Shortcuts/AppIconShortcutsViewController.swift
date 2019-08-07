//
//  AppIconShortcutsViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/19/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

import Roxas

@objc(SwitchTableViewCell)
private class SwitchTableViewCell: UITableViewCell
{
    @IBOutlet var switchView: UISwitch!
}

class AppIconShortcutsViewController: UITableViewController
{
    private lazy var dataSource = RSTCompositeTableViewPrefetchingDataSource<Game, UIImage>(dataSources: [self.modeDataSource, self.shortcutsDataSource, self.gamesDataSource])
    private let modeDataSource = RSTDynamicTableViewDataSource<Game>()
    private let shortcutsDataSource = RSTArrayTableViewPrefetchingDataSource<Game, UIImage>(items: [])
    private let gamesDataSource = RSTFetchedResultsTableViewPrefetchingDataSource<Game, UIImage>(fetchedResultsController: NSFetchedResultsController())
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.prepareDataSource()
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.register(GameTableViewCell.nib!, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.navigationItem.searchController = self.gamesDataSource.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        
        self.tableView.dataSource = self.dataSource
        self.tableView.allowsSelectionDuringEditing = true
        
        self.updateShortcuts()
    }
}

private extension AppIconShortcutsViewController
{
    func prepareDataSource()
    {
        // Mode
        self.modeDataSource.numberOfSectionsHandler = { 1 }
        self.modeDataSource.numberOfItemsHandler = { [weak self] _ in (self?.gamesDataSource.itemCount ?? 0) > 0 ? 1 : 0 }
        self.modeDataSource.cellIdentifierHandler = { _ in "SwitchCell" }
        
        // Shortcuts
        self.shortcutsDataSource.items = Settings.gameShortcuts
        
        // Games
        let gamesFetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        gamesFetchRequest.returnsObjectsAsFaults = false
        gamesFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.type, ascending: true), NSSortDescriptor(key: #keyPath(Game.name), ascending: true)]
        
        let gamesFetchedResultsController = NSFetchedResultsController(fetchRequest: gamesFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(Game.type), cacheName: nil)
        self.gamesDataSource.fetchedResultsController = gamesFetchedResultsController
        self.gamesDataSource.searchController.searchableKeyPaths = [#keyPath(Game.name)]
        
        // Data Source
        self.dataSource.proxy = self
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, game, indexPath) in
            if indexPath.section == 0
            {
                self.configureModeCell(cell as! SwitchTableViewCell, for: indexPath)
            }
            else
            {
                self.configureGameCell(cell as! GameTableViewCell, with: game, for: indexPath)
            }
        }
        self.dataSource.prefetchHandler = { (game, indexPath, completionHandler) in
            guard indexPath.section > 0 else { return nil }
            
            guard let artworkURL = game.artworkURL else { return nil }
            
            let imageOperation = LoadImageURLOperation(url: artworkURL)
            imageOperation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
            
            return imageOperation
        }
        self.dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard indexPath.section > 0 else { return }
            
            guard let image = image else { return }
            
            let cell = cell as! GameTableViewCell
            
            let artworkDisplaySize = AVMakeRect(aspectRatio: image.size, insideRect: cell.artworkImageView.bounds)
            let offset = (cell.artworkImageView.bounds.width - artworkDisplaySize.width) / 2
            
            // Offset artworkImageViewLeadingConstraint and artworkImageViewTrailingConstraint to right-align artworkImageView
            cell.artworkImageViewLeadingConstraint.constant += offset
            cell.artworkImageViewTrailingConstraint.constant -= offset
            
            cell.artworkImageView.image = image
            cell.artworkImageView.superview?.layoutIfNeeded()
        }
        self.dataSource.rowAnimation = .fade
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("No App Icon Shortcuts", comment: "")
        placeholderView.detailTextLabel.text = NSLocalizedString("You can customize the shortcuts that appear when 3D Touching the app icon once you've added some games.", comment: "")
        self.dataSource.placeholderView = placeholderView
    }
    
    func configureModeCell(_ cell: SwitchTableViewCell, for indexPath: IndexPath)
    {
        cell.textLabel?.text = NSLocalizedString("Recently Played Games", comment: "")
        cell.textLabel?.backgroundColor = .clear
        
        cell.switchView.isOn = (Settings.gameShortcutsMode == .recent)
        cell.switchView.onTintColor = self.view.tintColor
    }
    
    func configureGameCell(_ cell: GameTableViewCell, with game: Game, for indexPath: IndexPath)
    {
        cell.nameLabel.textColor = .darkText
        cell.backgroundColor = .white
        
        cell.nameLabel.text = game.name
        cell.artworkImageView.image = #imageLiteral(resourceName: "BoxArt")
        
        cell.artworkImageViewLeadingConstraint.constant = 15
        cell.artworkImageViewTrailingConstraint.constant = 15
        
        cell.separatorInset.left = cell.nameLabel.frame.minX
        
        cell.selectedBackgroundView = nil
        
        switch (indexPath.section, Settings.gameShortcutsMode)
        {
        case (1, _):
            cell.selectionStyle = .none
            cell.contentView.alpha = 1.0
            
        case (2..., .recent):
            cell.selectionStyle = .none
            cell.contentView.alpha = 0.3
            
        case (2..., .manual):
            cell.selectionStyle = .gray
            cell.contentView.alpha = 1.0
            
        default: break
        }
    }
}

private extension AppIconShortcutsViewController
{
    func updateShortcuts()
    {
        switch Settings.gameShortcutsMode
        {
        case .recent:
            let fetchRequest = Game.recentlyPlayedFetchRequest
            fetchRequest.returnsObjectsAsFaults = false
            
            do
            {
                let games = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
                self.shortcutsDataSource.setItems(games, with: [])
            }
            catch
            {
                print(error)
            }
            
            self.tableView.setEditing(false, animated: true)
            
        case .manual: self.tableView.setEditing(true, animated: true)
        }
        
        Settings.gameShortcuts = self.shortcutsDataSource.items        
    }
    
    func addShortcut(for game: Game)
    {
        guard self.shortcutsDataSource.items.count < 4 else { return }
        
        guard !self.shortcutsDataSource.items.contains(game) else { return }
        
        // No need to adjust destinationIndexPath, since it forwards change directly to table view.
        let destinationIndexPath = IndexPath(row: self.shortcutsDataSource.items.count, section: 1)
        
        let insertion = RSTCellContentChange(type: .insert, currentIndexPath: nil, destinationIndexPath: destinationIndexPath)
        insertion.rowAnimation = .fade
        
        var shortcuts = self.shortcutsDataSource.items
        shortcuts.insert(game, at: destinationIndexPath.row)
        self.shortcutsDataSource.setItems(shortcuts, with: [insertion])
        
        self.updateShortcuts()
    }
}

private extension AppIconShortcutsViewController
{
    @IBAction func switchGameShortcutsMode(with sender: UISwitch)
    {
        if sender.isOn
        {
            Settings.gameShortcutsMode = .recent
        }
        else
        {
            Settings.gameShortcutsMode = .manual
        }
        
        self.tableView.beginUpdates()
        
        self.updateShortcuts()
        self.tableView.reloadSections(IndexSet(integersIn: 0 ..< self.tableView.numberOfSections), with: .fade)
        
        self.tableView.endUpdates()
    }
}

extension AppIconShortcutsViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        guard indexPath.section == 0 else { return super.tableView(tableView, heightForRowAt: indexPath) }
        
        return 44
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard self.dataSource.itemCount > 0 else { return nil }
        
        switch section
        {
        case 0: return nil
        case 1: return NSLocalizedString("Shortcuts", comment: "")
        default:
            let gameType = GameType(rawValue: self.gamesDataSource.fetchedResultsController.sections![section - 2].name)
            
            let system = System(gameType: gameType)!
            return system.localizedName
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        guard self.dataSource.itemCount > 0 else { return nil }
        
        switch (section, Settings.gameShortcutsMode)
        {
        case (0, .recent): return NSLocalizedString("Your most recently played games will appear as shortcuts when 3D touching the app icon.", comment: "")
        case (0, .manual): return NSLocalizedString("The games you've selected below will appear as shortcuts when 3D touching the app icon.", comment: "")
        case (1, .recent): return " " // Return non-empty string since empty string changes vertical offset of section for some reason.
        case (1, .manual): return NSLocalizedString("You may have up to 4 shortcuts.", comment: "")
            
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard indexPath.section > 1 else { return }

        guard Settings.gameShortcutsMode == .manual else { return }

        tableView.deselectRow(at: indexPath, animated: true)

        let game = self.dataSource.item(at: indexPath)
        self.addShortcut(for: game)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        switch editingStyle
        {
        case .none: break
        case .delete:
            let deletion = RSTCellContentChange(type: .delete, currentIndexPath: indexPath, destinationIndexPath: nil)
            deletion.rowAnimation = .fade
            
            var shortcuts = self.shortcutsDataSource.items
            shortcuts.remove(at: indexPath.row) // No need to adjust indexPath, since it forwards change directly to table view.
            self.shortcutsDataSource.setItems(shortcuts, with: [deletion])
            
        case .insert:
            let game = self.dataSource.item(at: indexPath)
            self.addShortcut(for: game)
            
        @unknown default: break
        }
        
        self.updateShortcuts()
    }
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String?
    {
        return NSLocalizedString("Remove", comment: "")
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle
    {
        switch indexPath.section
        {
        case 1: return .delete
        case 2...: return .insert
        default: return .none
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool
    {
        return false
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool
    {
        return (indexPath.section == 1)
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
    {
        let indexPath: IndexPath
        
        switch proposedDestinationIndexPath.section
        {
        case 0: indexPath = IndexPath(row: 0, section: 1)
        case 1: indexPath = proposedDestinationIndexPath
        default: indexPath = IndexPath(row: self.shortcutsDataSource.items.count - 1, section: 1)
        }
        
        return indexPath
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
    {
        var items = self.shortcutsDataSource.items
        
        let game = items.remove(at: sourceIndexPath.row)
        items.insert(game, at: destinationIndexPath.row)
        
        self.shortcutsDataSource.items = items
        
        self.updateShortcuts()
    }
}
