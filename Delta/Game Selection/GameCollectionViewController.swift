//
//  GameCollectionViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import RegexBuilder

import DeltaCore
import MelonDSDeltaCore

import Roxas
import Harmony

import SDWebImage

extension GameCollectionViewController
{
    private enum LaunchError: LocalizedError
    {
        case alreadyRunning
        case downloadingGameSave
        case biosNotFound
        case systemAlreadyRunning(Game?, UISceneSession)
        
        var errorTitle: String? {
            switch self
            {
            case .alreadyRunning: return NSLocalizedString("Game Already Running", comment: "")
            case .downloadingGameSave: return NSLocalizedString("Downloading Save File", comment: "")
            case .biosNotFound: return NSLocalizedString("Missing Required DS Files", comment: "")
            case .systemAlreadyRunning: return NSLocalizedString("System Already Running", comment: "")
            }
        }
        
        var errorDescription: String? {
            switch self
            {
            case .alreadyRunning: return NSLocalizedString("Delta can only play one copy of a game at a time.", comment: "")
            case .downloadingGameSave: return NSLocalizedString("Please wait until after this game's save file has been downloaded before playing to prevent losing save data.", comment: "")
            case .biosNotFound: return NSLocalizedString("Please import the required files in Delta's settings to play DS games.", comment: "")
            case .systemAlreadyRunning(let game, _):
                var gameNamePhrase = ""
                if let game
                {
                    gameNamePhrase = String(format: " (“%@”)", game.name)
                }
                
                let message = String(format: NSLocalizedString("Delta can only play one game per system at a time.\n\nPlease quit the other game%@, or choose another game for a different system.", comment: ""), gameNamePhrase)
                return message
            }
        }
        
        var recoveryActions: [UIAlertAction] {
            switch self
            {
            case .systemAlreadyRunning(let game, let session):
                let quitAction = UIAlertAction(title: NSLocalizedString("Quit Game", comment: ""), style: .destructive) { _ in
                    session.quit()
                }
                return [quitAction]
                
            default: return []
            }
        }
    }
}

class GameCollectionViewController: UICollectionViewController
{
    var gameCollection: GameCollection? {
        didSet {
            self.title = self.gameCollection?.shortName
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
    
    internal let dataSource: RSTFetchedResultsCollectionViewPrefetchingDataSource<Game, UIImage>
    
    weak var activeEmulatorCore: EmulatorCore?
    
    private var activeSaveState: SaveStateProtocol?
    
    private let prototypeCell = GridCollectionViewCell()
    
    private var _performingPreviewTransition = false
    private weak var _previewTransitionViewController: PreviewGameViewController?
    private weak var _previewTransitionDestinationViewController: UIViewController?
    
    private weak var _popoverSourceView: UIView?
    
    private var _renameAction: UIAlertAction?
    private var _changingArtworkGame: Game?
    private var _importingSaveFileGame: Game?
    private var _exportedSaveFileURL: URL?
    
    required init?(coder aDecoder: NSCoder)
    {
        self.dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<Game, UIImage>(fetchedResultsController: NSFetchedResultsController())

        super.init(coder: aDecoder)
        
        self.prepareDataSource()
    }
}

//MARK: - UIViewController -
/// UIViewController
extension GameCollectionViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.prefetchDataSource = self.dataSource
        self.collectionView?.delegate = self
        
        if UIApplication.shared.supportsMultipleScenes
        {
            self.collectionView?.dragDelegate = self
        }
        
        self.update()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if _performingPreviewTransition
        {
            _performingPreviewTransition = false
            
            // Unlike our custom transitions, 3D Touch transition doesn't manually call appearance methods for us
            // To compensate, we call them ourselves
            _previewTransitionDestinationViewController?.beginAppearanceTransition(true, animated: true)
            
            self.transitionCoordinator?.animate(alongsideTransition: nil, completion: { (context) in
                self._previewTransitionDestinationViewController?.endAppearanceTransition()
                self._previewTransitionDestinationViewController = nil
            })
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.update()
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
        case "saveStates":
            let game = sender as! Game
            
            let saveStatesViewController = (segue.destination as! UINavigationController).topViewController as! SaveStatesViewController
            saveStatesViewController.delegate = self
            saveStatesViewController.game = game
            saveStatesViewController.mode = .loading
            saveStatesViewController.theme = self.theme
            
        case "preferredControllerSkins":
            let game = sender as! Game
            
            let preferredControllerSkinsViewController = (segue.destination as! UINavigationController).topViewController as! PreferredControllerSkinsViewController
            preferredControllerSkinsViewController.game = game

        case "unwindFromGames":
            let destinationViewController = segue.destination as! GameViewController
            let cell = sender as! UICollectionViewCell
            
            let indexPath = self.collectionView!.indexPath(for: cell)!
            let game = self.dataSource.item(at: indexPath)
            
            destinationViewController.game = game
            
            if let emulatorBridge = destinationViewController.emulatorCore?.deltaCore.emulatorBridge as? MelonDSEmulatorBridge
            {
                //TODO: Update this to work with multiple processes by retrieving emulatorBridge directly from emulatorCore.
                
                if game.identifier == Game.melonDSDSiBIOSIdentifier
                {
                    emulatorBridge.systemType = .dsi
                }
                else
                {
                    emulatorBridge.systemType = .ds
                }
                
                emulatorBridge.isJITEnabled = ProcessInfo.processInfo.isJITAvailable
                emulatorBridge.gbaGameURL = game.secondaryGame?.fileURL
            }
            
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
            
            if _performingPreviewTransition
            {
                _previewTransitionDestinationViewController = destinationViewController
            }
            
        default: break
        }
    }
    
    @IBAction private func unwindToGameCollectionViewController(_ segue: UIStoryboardSegue)
    {
    }
}

//MARK: - Private Methods -
private extension GameCollectionViewController
{
    func update()
    {
        let layout = self.collectionViewLayout as! GridCollectionViewLayout
        
        switch self.traitCollection.horizontalSizeClass
        {
        case .regular:
            layout.itemWidth = 150
            layout.minimumInteritemSpacing = 25 // 30 == only 3 games per line for iPad mini 6 in portrait
            
        case .unspecified, .compact:
            layout.itemWidth = 90
            layout.minimumInteritemSpacing = 12
            
        @unknown default: break
        }
        
        self.collectionView.reloadData()
    }
    
    //MARK: - Data Source
    func prepareDataSource()
    {
        self.dataSource.cellConfigurationHandler = { [weak self] (cell, item, indexPath) in
            self?.configure(cell as! GridCollectionViewCell, for: indexPath)
        }
        
        self.dataSource.prefetchHandler = { (game, indexPath, completionHandler) in
            guard let artworkURL = game.artworkURL else { return nil }
            
            let imageOperation = LoadImageURLOperation(url: artworkURL)
            imageOperation.resultHandler = { (image, error) in
                completionHandler(image, error)
            }
            
            return imageOperation
        }
        
        self.dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            guard let image = image else { return }
            
            let cell = cell as! GridCollectionViewCell
            cell.imageView.image = image
            cell.isImageViewVibrancyEnabled = false
        }
    }
    
    func updateDataSource()
    {
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        
        if let gameCollection = self.gameCollection
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.gameCollection), gameCollection)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Game.name), ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        self.dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
    }
    
    //MARK: - Configure Cells
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath)
    {
        let game = self.dataSource.item(at: indexPath)
        
        switch self.theme
        {
        case .opaque:
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
        case .translucent:
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
        }
        
        cell.imageView.shouldAlignBaselines = true
        cell.imageView.image = #imageLiteral(resourceName: "BoxArt")
        
        if game.identifier == Game.melonDSBIOSIdentifier || game.identifier == Game.melonDSDSiBIOSIdentifier
        {
            // Don't clip bounds to avoid clipping Home Screen icon.
            cell.imageView.clipsToBounds = false
        }
        else
        {
            cell.imageView.clipsToBounds = true
        }
        
        if self.traitCollection.horizontalSizeClass == .regular
        {
            let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline).withSymbolicTraits(.traitBold)!
            cell.textLabel.font = UIFont(descriptor: fontDescriptor, size: 0)
        }
        else
        {
            cell.textLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        }
        
        let layout = self.collectionViewLayout as! GridCollectionViewLayout
        cell.maximumImageSize = CGSize(width: layout.itemWidth, height: layout.itemWidth)
        
        cell.textLabel.text = game.name
        cell.textLabel.textColor = UIColor.gray
        cell.tintColor = cell.textLabel.textColor
    }
    
    //MARK: - Emulation
    func launchGame(at indexPath: IndexPath, clearScreen: Bool, ignoreAlreadyRunningError: Bool = false)
    {
        func launchGame(ignoringErrors ignoredErrors: [Error])
        {
            let game = self.dataSource.item(at: indexPath)
            
            do
            {
                try self.validateLaunchingGame(game, ignoringErrors: ignoredErrors)
                
                if clearScreen
                {
                    self.activeEmulatorCore?.gameViews.forEach { $0.inputImage = nil }
                }
                
                let cell = self.collectionView.cellForItem(at: indexPath)
                self.performSegue(withIdentifier: "unwindFromGames", sender: cell)
            }
            catch let error as LaunchError
            {
                switch error
                {
                case .alreadyRunning:
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
                        
                        launchGame(ignoringErrors: [LaunchError.alreadyRunning])
                        
                        // The game hasn't changed, so the activeEmulatorCore is the same as before, so we need to enable videoManager it again
                        self.activeEmulatorCore?.videoManager.isEnabled = true
                    }))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Restart", comment: ""), style: .destructive, handler: { (action) in
                        launchGame(ignoringErrors: [LaunchError.alreadyRunning])
                    }))
                    self.present(alertController, animated: true)
                    
                case .biosNotFound:
                    let alertController = UIAlertController(title: NSLocalizedString("Missing Required DS Files", comment: ""), message: NSLocalizedString("Delta requires certain files to play Nintendo DS games. Please import them to launch this game.", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Import Files", comment: ""), style: .default) { _ in
                        self.performSegue(withIdentifier: "showDSSettings", sender: nil)
                    })
                    alertController.addAction(.cancel)
                    
                    self.present(alertController, animated: true, completion: nil)
                    
                case .downloadingGameSave, .systemAlreadyRunning:
                    let alertController = UIAlertController(title: error.errorTitle, message: error.localizedDescription, preferredStyle: .alert)
                    
                    if error.recoveryActions.isEmpty
                    {
                        alertController.addAction(.ok)
                    }
                    else
                    {
                        alertController.addAction(.cancel)
                        
                        for action in error.recoveryActions
                        {
                            alertController.addAction(action)
                        }
                    }
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Launch Game", comment: ""), error: error)
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        if ignoreAlreadyRunningError
        {
            launchGame(ignoringErrors: [LaunchError.alreadyRunning])
        }
        else
        {
            launchGame(ignoringErrors: [])
        }
    }
    
    func validateLaunchingGame(_ game: Game, ignoringErrors ignoredErrors: [Error]) throws
    {
        let ignoredErrors = ignoredErrors.map { $0 as NSError }
        
        if !ignoredErrors.contains(where: { $0.domain == (LaunchError.alreadyRunning as NSError).domain && $0.code == (LaunchError.alreadyRunning as NSError).code })
        {
            guard game.fileURL != self.activeEmulatorCore?.game.fileURL else { throw LaunchError.alreadyRunning }
        }
        
        if let scene = self.view.window?.windowScene
        {
            // Check connectedScenes, not openSessions, because a disconnected scene restarts from home screen (so it's not an issue).
            for mainScene in UIApplication.shared.mainScenes where mainScene != scene
            {
                guard let delegate = mainScene.delegate as? SceneDelegate else { continue }
                
                if let otherGame = delegate.game, otherGame.type == game.type
                {
                    // Can't emulate multiple games from same system simultaneously.
                    throw LaunchError.systemAlreadyRunning(otherGame, mainScene.session)
                }
            }
            
            for session in UIApplication.shared.gameSessions where session != scene.session
            {
                if let systemID = session.userInfo?[NSUserActivity.systemIDKey] as? String, systemID == game.type.rawValue
                {
                    var otherGame: Game?
                    if let gameID = session.userInfo?[NSUserActivity.gameIDKey] as? String
                    {
                        let predicate = NSPredicate(format: "%K == %@", #keyPath(Game.identifier), gameID)
                        otherGame = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self).first
                    }
                    
                    // Can't emulate multiple games from same system simultaneously.
                    throw LaunchError.systemAlreadyRunning(otherGame, session)
                }
            }
        }
        
        if let coordinator = SyncManager.shared.coordinator, coordinator.isSyncing
        {
            if let gameSave = game.gameSave
            {
                do
                {
                    if let record = try coordinator.recordController.fetchRecords(for: [gameSave]).first
                    {
                        if record.isSyncingEnabled && !record.isConflicted && (record.localStatus == nil || record.remoteStatus == .updated)
                        {
                            throw LaunchError.downloadingGameSave
                        }
                    }
                }
                catch let error as LaunchError
                {
                    throw error
                }
                catch
                {
                    print("Error fetching record for game save.", error)
                }
            }
        }
        
        if game.type == .ds && Settings.preferredCore(for: .ds) == MelonDS.core
        {
            if game.identifier == Game.melonDSDSiBIOSIdentifier
            {
                guard
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiBIOS7URL.path) &&
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiBIOS9URL.path) &&
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiFirmwareURL.path) &&
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.dsiNANDURL.path)
                else { throw LaunchError.biosNotFound }
            }
            else if game.identifier == Game.melonDSBIOSIdentifier
            {
                guard
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios7URL.path) &&
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios9URL.path) &&
                    FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path)
                else { throw LaunchError.biosNotFound }
            }
            else
            {
                // BIOS files are only required to emulate DS(i) home screen.
            }
        }
    }
}

//MARK: - Game Actions -
private extension GameCollectionViewController
{
    func actions(for game: Game) -> [UIMenuElement]
    {
        let openNewWindowAction = UIAction(title: NSLocalizedString("Open in New Window", comment: ""), image: UIImage(symbolNameIfAvailable: "square.grid.2x2")) { [unowned self] action in
            self.openInNewWindow(game)
        }
        
        let renameAction = UIAction(title: NSLocalizedString("Rename", comment: ""), image: UIImage(symbolNameIfAvailable: "pencil")) { [unowned self] action in
            self.rename(game)
        }
        
        let changeArtworkAction = UIAction(title: NSLocalizedString("Change Artwork", comment: ""), image: UIImage(symbolNameIfAvailable: "photo")) { [unowned self] action in
            self.changeArtwork(for: game)
        }
        
        let changeControllerSkinAction = UIAction(title: NSLocalizedString("Change Controller Skin", comment: ""), image: UIImage(symbolNameIfAvailable: "gamecontroller")) { [unowned self] _ in
            self.changePreferredControllerSkin(for: game)
        }
        
        let shareAction = UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(symbolNameIfAvailable: "square.and.arrow.up")) { [unowned self] action in
            self.share(game)
        }
        
        let saveStatesAction = UIAction(title: NSLocalizedString("View Save States", comment: ""), image: UIImage(symbolNameIfAvailable: "doc.on.doc")) { [unowned self] action in
            self.viewSaveStates(for: game)
        }
        
        let importSaveFile = UIAction(title: NSLocalizedString("Import Save File", comment: ""), image: UIImage(symbolNameIfAvailable: "tray.and.arrow.down")) { [unowned self] _ in
            self.importSaveFile(for: game)
        }
        
        let exportSaveFile = UIAction(title: NSLocalizedString("Export Save File", comment: ""), image: UIImage(symbolNameIfAvailable: "tray.and.arrow.up")) { [unowned self] _ in
            self.exportSaveFile(for: game)
        }
        
        let deleteAction = UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(symbolNameIfAvailable: "trash"), attributes: .destructive) { [unowned self] action in
            self.delete(game)
        }
        
        let openMenu = UIMenu(title: "", options: .displayInline, children: [openNewWindowAction])
        let openActions = UIApplication.shared.supportsMultipleScenes ? [openMenu] : []
        
        let saveFileMenu = UIMenu(title: NSLocalizedString("Manage Save File", comment: ""), image: UIImage(symbolNameIfAvailable: "doc"), children: [importSaveFile, exportSaveFile])
        let savesMenu = UIMenu(title: "", options: .displayInline, children: [saveStatesAction, saveFileMenu])
        
        switch game.type
        {
        case GameType.unknown:
            return [renameAction, changeArtworkAction, shareAction, deleteAction]
            
        case .ds where game.identifier == Game.melonDSBIOSIdentifier || game.identifier == Game.melonDSDSiBIOSIdentifier:
            return openActions + [renameAction, changeArtworkAction, changeControllerSkinAction, saveStatesAction]
            
        case .ds:
            let insertGBAGameMenu = self.insertGBAGameMenu(for: game)
            let insertGBAGameSection = UIMenu(title: "", image: nil, options: .displayInline, children: [insertGBAGameMenu])
            return openActions + [renameAction, changeArtworkAction, changeControllerSkinAction, shareAction, savesMenu, insertGBAGameSection, deleteAction]
            
        default:
            return openActions + [renameAction, changeArtworkAction, changeControllerSkinAction, shareAction, savesMenu, deleteAction]
        }
    }
    
    func openInNewWindow(_ game: Game)
    {
        do
        {
            try self.validateLaunchingGame(game, ignoringErrors: [])
            
            let userActivity = NSUserActivity(game: game)
            
            if #available(iOS 17, *)
            {
                let request = UISceneSessionActivationRequest(role: .windowApplication, userActivity: userActivity)
                UIApplication.shared.activateSceneSession(for: request) { error in
                    Logger.main.error("Failed to open game \(game.name, privacy: .public) in new window. \(error.localizedDescription, privacy: .public)")
                }
            }
            else
            {
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil) { error in
                    Logger.main.error("Failed to open game \(game.name, privacy: .public) in new window. \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        catch let error as LaunchError
        {
            let alertController = UIAlertController(title: error.errorTitle, message: error.localizedDescription, preferredStyle: .alert)
            
            if error.recoveryActions.isEmpty
            {
                alertController.addAction(.ok)
            }
            else
            {
                alertController.addAction(.cancel)
                
                for action in error.recoveryActions
                {
                    alertController.addAction(action)
                }
            }
            
            self.present(alertController, animated: true, completion: nil)
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Unable to Launch Game", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(.ok)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func delete(_ game: Game)
    {
        let confirmationAlertController = UIAlertController(title: NSLocalizedString("Are you sure you want to delete this game?", comment: ""),
                                                            message: NSLocalizedString("All associated data, such as saves, save states, and cheat codes, will also be deleted.", comment: ""),
                                                            preferredStyle: .alert)
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
        self.performSegue(withIdentifier: "saveStates", sender: game)
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
        guard name.count > 0 else { return }

        DatabaseManager.shared.performBackgroundTask { (context) in
            let game = context.object(with: game.objectID) as! Game
            game.name = name
            
            context.saveWithErrorLogging()
        }
        
        self._renameAction = nil
    }
    
    func changeArtwork(for game: Game)
    {
        self._changingArtworkGame = game
        
        let clipboardImportOption = ClipboardImportOption()
        let photoLibraryImportOption = PhotoLibraryImportOption(presentingViewController: self)
        
        var sanitizedGameName = game.name
        
        if #available(iOS 16, *)
        {
            // Remove parentheses + everything inside.
            
            let regex = Regex {
                "("
                OneOrMore(.anyNonNewline)
                ")"
            }
            
            sanitizedGameName = sanitizedGameName.replacing(regex, with: "")
        }
        
        sanitizedGameName = sanitizedGameName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let gamesDatabaseImportOption = GamesDatabaseImportOption(searchText: sanitizedGameName, presentingViewController: self)
        
        let importController = ImportController(documentTypes: [kUTTypeImage as String])
        importController.delegate = self
        importController.importOptions = [clipboardImportOption, photoLibraryImportOption, gamesDatabaseImportOption]
        importController.sourceView = self._popoverSourceView
        self.present(importController, animated: true, completion: nil)
    }
    
    func changeArtwork(for game: Game, toImageAt url: URL?, errors: [Error])
    {
        defer {
            if let temporaryImageURL = url
            {
                try? FileManager.default.removeItem(at: temporaryImageURL)
            }
        }
        
        var errors = errors
        
        var imageURL: URL?
        
        if let url = url
        {
            if url.isFileURL
            {
                do
                {
                    let imageData = try Data(contentsOf: url)
                    
                    if
                        let image = UIImage(data: imageData),
                        let resizedImage = image.resizing(toFit: CGSize(width: 300, height: 300)),
                        let rotatedImage = resizedImage.rotatedToIntrinsicOrientation(), // in case image was imported directly from Files
                        let resizedData = rotatedImage.pngData()
                    {
                        let destinationURL = DatabaseManager.artworkURL(for: game)
                        try resizedData.write(to: destinationURL, options: .atomic)
                        
                        imageURL = destinationURL
                    }
                }
                catch
                {
                    errors.append(error)
                }
            }
            else
            {
                imageURL = url
            }
        }
        
        for error in errors
        {
            print(error)
        }
        
        if let imageURL = imageURL
        {
            self.dataSource.prefetchItemCache.removeObject(forKey: game)
            
            if let cacheManager = SDWebImageManager.shared()
            {
                let cacheKey = cacheManager.cacheKey(for: imageURL)
                cacheManager.imageCache.removeImage(forKey: cacheKey)
            }
            
            DatabaseManager.shared.performBackgroundTask { (context) in
                let temporaryGame = context.object(with: game.objectID) as! Game
                temporaryGame.artworkURL = imageURL
                context.saveWithErrorLogging()
                
                // Local image URLs may not change despite being a different image, so manually mark record as updated.
                SyncManager.shared.recordController?.updateRecord(for: temporaryGame)
                
                DispatchQueue.main.async {
                    if let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: game)
                    {
                        // Manually reload item because collection view may not be in window hierarchy,
                        // which means it won't automatically update when we save the context.
                        self.collectionView.reloadItems(at: [indexPath])
                    }
                    
                    self.presentedViewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
        else
        {
            DispatchQueue.main.async {
                func presentAlertController()
                {
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Change Artwork", comment: ""), message: NSLocalizedString("The image might be corrupted or in an unsupported format.", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
                
                if let presentedViewController = self.presentedViewController
                {
                    presentedViewController.dismiss(animated: true) {
                        presentAlertController()
                    }
                }
                else
                {
                    presentAlertController()
                }
            }
        }
    }
    
    func share(_ game: Game)
    {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        let sanitizedName = game.name.components(separatedBy: .urlFilenameAllowed.inverted).joined()
        let temporaryURL = temporaryDirectory.appendingPathComponent(sanitizedName + "." + game.fileURL.pathExtension, isDirectory: false)
        
        do
        {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
                                    
            // Make a temporary copy so we can control the filename used when sharing.
            // Otherwise, if we just passed in game.fileURL to UIActivityViewController, the file name would be the game's SHA1 hash.
            try FileManager.default.copyItem(at: game.fileURL, to: temporaryURL, shouldReplace: true)
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Could Not Share Game", comment: ""), error: error)
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        let copyDeepLinkActivity = CopyDeepLinkActivity()
        
        let activityViewController = UIActivityViewController(activityItems: [temporaryURL, game], applicationActivities: [copyDeepLinkActivity])
        activityViewController.popoverPresentationController?.sourceView = self._popoverSourceView?.superview
        activityViewController.popoverPresentationController?.sourceRect = self._popoverSourceView?.frame ?? .zero
        activityViewController.completionWithItemsHandler = { (activityType, finished, returnedItems, error) in
            // Make sure the user either shared the game or cancelled before deleting temporaryDirectory.
            guard finished || activityType == nil else { return }
            
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
    
    func importSaveFile(for game: Game)
    {
        self._importingSaveFileGame = game
        
        let importController = ImportController(documentTypes: [kUTTypeItem as String])
        importController.delegate = self
        self.present(importController, animated: true, completion: nil)
    }
    
    func importSaveFile(for game: Game, from fileURL: URL?, error: Error?)
    {
        // Dispatch to main queue so we can access game.gameSaveURL on its context's thread (main thread).
        DispatchQueue.main.async {
            do
            {
                if let error = error
                {
                    throw error
                }
                
                if let fileURL = fileURL
                {
                    try FileManager.default.copyItem(at: fileURL, to: game.gameSaveURL, shouldReplace: true)
                    
                    if let gameSave = game.gameSave
                    {
                        SyncManager.shared.recordController?.updateRecord(for: gameSave)
                    }
                }
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Failed to Import Save File", comment: ""), error: error)
                
                if let presentedViewController = self.presentedViewController
                {
                    presentedViewController.dismiss(animated: true) {
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
                else
                {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    func exportSaveFile(for game: Game)
    {
        do
        {
            let sanitizedFilename = game.name.components(separatedBy: .urlFilenameAllowed.inverted).joined()
            
            let saveFileExtension: String
            if let deltaCore = Delta.core(for: game.type)
            {
                saveFileExtension = deltaCore.gameSaveFileExtension
            }
            else
            {
                saveFileExtension = "sav"
            }
            
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(sanitizedFilename).appendingPathExtension(saveFileExtension)
            try FileManager.default.copyItem(at: game.gameSaveURL, to: temporaryURL, shouldReplace: true)
            
            self._exportedSaveFileURL = temporaryURL
            
            let documentPicker = UIDocumentPickerViewController(urls: [temporaryURL], in: .exportToService)
            documentPicker.delegate = self
            self.present(documentPicker, animated: true, completion: nil)
        }
        catch
        {
            let alertController = UIAlertController(title: NSLocalizedString("Failed to Export Save File", comment: ""), error: error)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func changePreferredControllerSkin(for game: Game)
    {
        self.performSegue(withIdentifier: "preferredControllerSkins", sender: game)
    }
    
    func insertGBAGameMenu(for game: Game) -> UIMenu
    {
        func makeAction(for gbaGame: Game?) -> UIMenuElement
        {
            let state: UIAction.State = (gbaGame == game.secondaryGame) ? .on : .off
            
            if let gbaGame
            {
                return UIAction(title: gbaGame.name, state: state) { _ in
                    DatabaseManager.shared.performBackgroundTask { (context) in
                        let temporaryGame = context.object(with: game.objectID) as! Game
                        let temporarySecondaryGame = context.object(with: gbaGame.objectID) as! Game
                        
                        temporaryGame.secondaryGame = temporarySecondaryGame
                        context.saveWithErrorLogging()
                    }
                }
            }
            else
            {
                return UIAction(title: NSLocalizedString("None", comment: ""), state: state) { _ in
                    DatabaseManager.shared.performBackgroundTask { (context) in
                        let temporaryGame = context.object(with: game.objectID) as! Game
                        temporaryGame.secondaryGame = nil
                        context.saveWithErrorLogging()
                    }
                }
            }
        }
        
        let actions: [UIMenuElement]
        
        if FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios7URL.path) &&
            FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.bios9URL.path) &&
            FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path)
        {
            func makeElements(completion: @escaping ([UIMenuElement]) -> Void)
            {
                let fetchRequest = Game.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Game.type), System.gba.gameType.rawValue)
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.name, ascending: true)]
                
                do
                {
                    let games = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
                    
                    let actions = games.map { game in
                        makeAction(for: game)
                    }
                    completion(actions)
                }
                catch
                {
                    Logger.main.error("Failed to fetch GBA games. \(error.localizedDescription, privacy: .public)")
                    completion([])
                }
            }
            
            let deferredActions: UIDeferredMenuElement
            if #available(iOS 15, *)
            {
                deferredActions = UIDeferredMenuElement.uncached(makeElements)
            }
            else
            {
                deferredActions = UIDeferredMenuElement(makeElements)
            }
            
            let noneAction = makeAction(for: nil)
            let noneMenu = UIMenu(options: .displayInline, children: [noneAction])
            
            actions = [noneMenu, deferredActions]
        }
        else
        {
            // BIOS is required for GBA slot emulation.
            
            let importBIOSAction = UIAction(title: NSLocalizedString("Import BIOS Files", comment: ""), image: UIImage(symbolNameIfAvailable: "square.and.arrow.down.on.square")) { _ in
                self.performSegue(withIdentifier: "showDSSettings", sender: nil)
            }
            let importBIOSMenu = UIMenu(title: NSLocalizedString("This feature requires Nintendo DS BIOS files.", comment: ""), options: .displayInline, children: [importBIOSAction])
            
            actions = [importBIOSMenu]
        }
        
        let menu = UIMenu(title: NSLocalizedString("Insert GBA Game", comment: ""), image: UIImage(symbolNameIfAvailable: "arrow.down.to.line.compact"), children: actions)
        return menu
    }
}

private extension GameCollectionViewController
{
    @objc func textFieldTextDidChange(_ textField: UITextField)
    {
        let text = textField.text ?? ""
        self._renameAction?.isEnabled = text.count > 0
    }
}

//MARK: - UIViewControllerPreviewingDelegate -
/// UIViewControllerPreviewingDelegate
extension GameCollectionViewController: UIViewControllerPreviewingDelegate
{
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard self.gameCollection?.identifier != GameType.unknown.rawValue else { return nil }
        
        guard
            let collectionView = self.collectionView,
            let indexPath = collectionView.indexPathForItem(at: location),
            let layoutAttributes = collectionView.layoutAttributesForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = layoutAttributes.frame
        
        let cell = collectionView.cellForItem(at: indexPath)
        self._popoverSourceView = cell
        
        let game = self.dataSource.item(at: indexPath)
        
        let gameViewController = self.makePreviewGameViewController(for: game)
        _previewTransitionViewController = gameViewController
        return gameViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        self.commitPreviewTransition()
    }
    
    func makePreviewGameViewController(for game: Game) -> PreviewGameViewController
    {
        let gameViewController = PreviewGameViewController()
        gameViewController.game = game
        
        if let previewSaveState = game.previewSaveState
        {
            gameViewController.previewSaveState = previewSaveState
            gameViewController.previewImage = UIImage(contentsOfFile: previewSaveState.imageFileURL.path)
        }
        
        if let emulatorBridge = gameViewController.emulatorCore?.deltaCore.emulatorBridge as? MelonDSEmulatorBridge
        {
            //TODO: Update this to work with multiple processes by retrieving emulatorBridge directly from emulatorCore.

            if game.identifier == Game.melonDSDSiBIOSIdentifier
            {
                emulatorBridge.systemType = .dsi
            }
            else
            {
                emulatorBridge.systemType = .ds
            }

            emulatorBridge.isJITEnabled = ProcessInfo.processInfo.isJITAvailable
        }
        
        return gameViewController
    }
    
    func commitPreviewTransition()
    {
        guard let gameViewController = _previewTransitionViewController else { return }
        
        let game = gameViewController.game as! Game
        gameViewController.pauseEmulation()
        
        let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: game)!
        let fileURL = FileManager.default.uniqueTemporaryURL()
        
        if gameViewController.isLivePreview
        {
            self.activeSaveState = gameViewController.emulatorCore?.saveSaveState(to: fileURL)
        }
        else
        {
            self.activeSaveState = gameViewController.previewSaveState
        }
        
        gameViewController.emulatorCore?.stop()
        
        _performingPreviewTransition = true
        
        self.launchGame(at: indexPath, clearScreen: true, ignoreAlreadyRunningError: true)
        
        if gameViewController.isLivePreview
        {
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
            self.launchGame(at: indexPath, clearScreen: false, ignoreAlreadyRunningError: true)
        }
    }
}

//MARK: - ImportControllerDelegate -
/// ImportControllerDelegate
extension GameCollectionViewController: ImportControllerDelegate
{
    func importController(_ importController: ImportController, didImportItemsAt urls: Set<URL>, errors: [Error])
    {
        if let game = self._changingArtworkGame
        {
            self.changeArtwork(for: game, toImageAt: urls.first, errors: errors)
        }
        else if let game = self._importingSaveFileGame
        {
            self.importSaveFile(for: game, from: urls.first, error: errors.first)
        }
        
        self._changingArtworkGame = nil
        self._importingSaveFileGame = nil
    }
    
    func importControllerDidCancel(_ importController: ImportController)
    {
        self.presentedViewController?.dismiss(animated: true, completion: nil)
    }
}

//MARK: - UICollectionViewDelegate -
/// UICollectionViewDelegate
extension GameCollectionViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        guard self.gameCollection?.identifier != GameType.unknown.rawValue else { return }
        
        self.launchGame(at: indexPath, clearScreen: true)
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
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size
    }
}

@available(iOS 13.0, *)
extension GameCollectionViewController
{
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let game = self.dataSource.item(at: indexPath)
        let actions = self.actions(for: game)
        
        let cell = self.collectionView.cellForItem(at: indexPath)
        self._popoverSourceView = cell
                
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: { [weak self] in
            guard let self = self else { return nil }
            
            do
            {
                try self.validateLaunchingGame(game, ignoringErrors: [LaunchError.alreadyRunning])
            }
            catch
            {
                print("Error trying to preview game:", error)
                return nil
            }
                        
            let previewViewController = self.makePreviewGameViewController(for: game)
            previewViewController.isLivePreview = Settings.isPreviewsEnabled
            
            guard previewViewController.isLivePreview || previewViewController.previewSaveState != nil else { return nil }
            self._previewTransitionViewController = previewViewController
            
            return previewViewController
        }) { suggestedActions in
            return UIMenu(title: game.name, children: actions)
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
        
        if let image = cell.imageView.image
        {
            var artworkFrame = AVMakeRect(aspectRatio: image.size, insideRect: cell.imageView.bounds)
            artworkFrame.origin.y = cell.imageView.bounds.height - artworkFrame.height
            
            let bezierPath = UIBezierPath(rect: artworkFrame)
            parameters.visiblePath = bezierPath
        }

        let preview = UITargetedPreview(view: cell.imageView, parameters: parameters)
        return preview
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        _previewTransitionViewController = nil
        return self.collectionView(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }
}

extension GameCollectionViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        if let saveFileURL = self._exportedSaveFileURL
        {
            try? FileManager.default.removeItem(at: saveFileURL)
        }
        
        self._exportedSaveFileURL = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        if let saveFileURL = self._exportedSaveFileURL
        {
            try? FileManager.default.removeItem(at: saveFileURL)
        }
        
        self._exportedSaveFileURL = nil
    }
}

extension GameCollectionViewController: UICollectionViewDragDelegate
{
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] 
    {
        do
        {
            let game = self.dataSource.item(at: indexPath)
            try self.validateLaunchingGame(game, ignoringErrors: [])
            
            let userActivity = NSUserActivity(game: game)
            
            let itemProvider = NSItemProvider()
            itemProvider.registerObject(userActivity, visibility: .all)
                    
            return [UIDragItem(itemProvider: itemProvider)]
        }
        catch
        {
            Logger.main.error("Error validating dragging game. \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
