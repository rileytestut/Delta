//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import MobileCoreServices

import DeltaCore

import Roxas
import Harmony
import SwiftUI

private var pageKey: Int = 0

extension GameCollectionViewController
{
    fileprivate var page: Page?
    {
        get {
            objc_getAssociatedObject(self, &pageKey) as? Page
        }
        set {
            objc_setAssociatedObject(self, &pageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

fileprivate enum Page: Equatable
{
    case favorites
    case recentlyPlayed
    case gameCollection(GameCollection)
    
    var pageIndicator: PageIndicator
    {
        switch self
        {
        case .favorites:
            return PageIndicator(id: "favorites", image: UIImage(systemName: "star.fill")!, alwaysShowsImage: true)
        case .recentlyPlayed:
            return PageIndicator(id: "recentlyPlayed", image: UIImage(systemName: "clock.fill")!, alwaysShowsImage: true, imageScale: 0.8)
        case .gameCollection(let collection):
            let icon = collection.system?.controllerIcon ?? UIImage(systemName: "gamecontroller.fill")!
            return PageIndicator(id: collection.identifier, image: icon)
        }
    }
}

class GamesViewController: UIViewController
{
    var theme: Theme = .opaque {
        didSet {
            self.updateTheme()
        }
    }
    
    private var hasRecentlyPlayed: Bool = false
    
    weak var activeEmulatorCore: EmulatorCore? {
        didSet
        {
            let game = oldValue?.game as? Game
            NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextObjectsDidChange, object: game?.managedObjectContext)
            
            if let game = self.activeEmulatorCore?.game as? Game
            {
                NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.managedObjectContextDidChange(with:)), name: .NSManagedObjectContextObjectsDidChange, object: game.managedObjectContext)
            }
            
            if #available(iOS 16, *)
            {
                self.resumeButton?.isHidden = (self.activeEmulatorCore?.game == nil)
            }
        }
    }
    
    fileprivate var pages: [Page] {
        var result: [Page] = []
        let gameCollections = self.fetchedResultsController.fetchedObjects as? [GameCollection] ?? []
        if !gameCollections.isEmpty {
            result.append(.favorites)
        }
        if self.hasRecentlyPlayed {
            result.append(.recentlyPlayed)
        }
        result += gameCollections.map { .gameCollection($0) }
        return result
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private var pageViewController: UIPageViewController!
    private var placeholderView: RSTPlaceholderView!
    private var pageControl: PageControlView!
    
    private let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    private let favoritesFetchedResultsController: NSFetchedResultsController<Game>
    private let recentlyPlayedFetchedResultsController: NSFetchedResultsController<Game>
    
    private var searchController: RSTSearchController?
    private lazy var importController: ImportController = self.makeImportController()
    
    private var syncingToastView: RSTToastView? {
        didSet {
            if self.syncingToastView == nil
            {
                self.syncingProgressObservation = nil
            }
        }
    }
    private var syncingProgressObservation: NSKeyValueObservation?
    
    private var resumeButton: UIBarButtonItem?
    @IBOutlet private var importButton: UIBarButtonItem!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("initWithNibName: not implemented")
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        let fetchRequest = GameCollection.rst_fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(GameCollection.index), ascending: true)]
                
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let favoritesFetchRequest = Game.favoritesFetchRequest
        favoritesFetchRequest.fetchLimit = 1
        self.favoritesFetchedResultsController = NSFetchedResultsController<Game>(fetchRequest: favoritesFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let recentlyPlayedFetchRequest = Game.fetchRequest() as NSFetchRequest<Game>
        recentlyPlayedFetchRequest.fetchLimit = 1
        recentlyPlayedFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.playedDate, ascending: false)]
        recentlyPlayedFetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Game.playedDate), #keyPath(Game.playedDate))
        self.recentlyPlayedFetchedResultsController = NSFetchedResultsController<Game>(fetchRequest: recentlyPlayedFetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init(coder: aDecoder)
        
        self.fetchedResultsController.delegate = self
        self.favoritesFetchedResultsController.delegate = self
        self.recentlyPlayedFetchedResultsController.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.syncingDidStart(_:)), name: SyncCoordinator.didStartSyncingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.syncingDidFinish(_:)), name: SyncCoordinator.didFinishSyncingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.settingsDidChange(_:)), name: Settings.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.emulationDidQuit(_:)), name: EmulatorCore.emulationDidQuitNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GamesViewController.didFinishAuthenticatingAchievementsAccount(_:)), name: AchievementsManager.didFinishAuthenticatingNotification, object: nil)
    }
}

//MARK: - UIViewController -
/// UIViewController
extension GamesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let faqButton = UIButton(type: .system)
        faqButton.addTarget(self, action: #selector(GamesViewController.openFAQ), for: .primaryActionTriggered)
        faqButton.setTitle(NSLocalizedString("Learn More…", comment: ""), for: .normal)
        faqButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
                
        self.placeholderView = RSTPlaceholderView(frame: self.view.bounds)
        self.placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.placeholderView.textLabel.text = NSLocalizedString("No Games", comment: "")
        self.placeholderView.detailTextLabel.text = NSLocalizedString("You can import games by pressing the + button in the top right.", comment: "")
        self.placeholderView.stackView.addArrangedSubview(faqButton)
        self.placeholderView.stackView.setCustomSpacing(20.0, after: self.placeholderView.detailTextLabel)
        self.view.insertSubview(self.placeholderView, at: 0)

        // Operator: install cartridge status overlay on placeholder
        self.configureOperatorOverlay(placeholderStackView: self.placeholderView.stackView)
        
        self.pageControl = PageControlView()
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 26, *)
        {
            self.view.addSubview(self.pageControl)
            self.pageControl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            self.pageControl.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        }
        else
        {
            self.navigationController?.toolbar.addSubview(self.pageControl)
            self.pageControl.centerXAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerXAnchor)!).isActive = true
            self.pageControl.centerYAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerYAnchor)!).isActive = true
        }
        
        self.pageControl.model.onPageSelected = { [weak self] index, animated in
            guard let self, let viewController = self.viewControllerForIndex(index) else { return }

            let direction: UIPageViewController.NavigationDirection =
                index > self.pageControl.model.currentPage ? .forward : .reverse

            self.pageViewController.setViewControllers([viewController], direction: direction, animated: animated, completion: nil)

            self.title = viewController.title
            self.pageControl.model.currentPage = index
        }

        if #available(iOS 26.0, *)
        {
            let resumeButton = UIBarButtonItem(image: UIImage(systemName: "play"), style: .prominent, target: self, action:  #selector(GamesViewController.resumeGame))
            resumeButton.isHidden = true
            self.resumeButton = resumeButton
            
            self.navigationItem.setRightBarButtonItems([self.importButton, resumeButton], animated: false)
        }
        else
        {
            let resumeButton = UIBarButtonItem(title: NSLocalizedString("Resume", comment: ""), style: .done, target: self, action: #selector(GamesViewController.resumeGame))
            resumeButton.isHidden = true
            self.resumeButton = resumeButton
            
            self.setToolbarItems([.flexibleSpace(), resumeButton], animated: false)
        }
        
        if let navigationController = self.navigationController
        {
            navigationController.overrideUserInterfaceStyle = .dark
            
            if #unavailable(iOS 26)
            {
                let navigationBarAppearance = navigationController.navigationBar.standardAppearance.copy()
                navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .dark)
                navigationController.navigationBar.standardAppearance = navigationBarAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navigationBarAppearance
                
                let toolbarAppearance = navigationController.toolbar.standardAppearance.copy()
                toolbarAppearance.backgroundEffect = UIBlurEffect(style: .dark)
                navigationController.toolbar.standardAppearance = toolbarAppearance
                navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
            }
        }
        
        self.importController.barButtonItem = self.importButton
        
        self.navigationItem.leftBarButtonItem?.accessibilityLabel = NSLocalizedString("Settings", comment: "")
        
        self.prepareSearchController()
        
        self.updateTheme()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        let favoritesDidFetch = self.favoritesFetchedResultsController.performFetchIfNeeded()
        let recentlyPlayedDidFetch = self.recentlyPlayedFetchedResultsController.performFetchIfNeeded()
        let collectionsDidFetch = self.fetchedResultsController.performFetchIfNeeded()
        
        if favoritesDidFetch || recentlyPlayedDidFetch || collectionsDidFetch
        {
            self.updateSections(animated: false)
        }
        
        if let activeEmulatorCore, !activeEmulatorCore.isWirelessMultiplayerActive
        {
            DispatchQueue.global().async {
                activeEmulatorCore.stop()
            }
        }
        
        self.sync()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        let whatsNewVersion = UserDefaults.standard.previousWhatsNewVersion ?? "0"
        let isUpdatedWhatsNew = (whatsNewVersion.compare(UserDefaults.whatsNewVersion, options: .numeric) == .orderedAscending)
        
        if !UserDefaults.standard.didShowWhatsNew || isUpdatedWhatsNew
        {
            self.performSegue(withIdentifier: "showWhatsNew", sender: nil)
            UserDefaults.standard.didShowWhatsNew = true
            UserDefaults.standard.previousWhatsNewVersion = UserDefaults.whatsNewVersion
        }
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - Segues -
/// Segues
extension GamesViewController
{
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedPageViewController":
            self.pageViewController = segue.destination as? UIPageViewController
            self.pageViewController.dataSource = self
            self.pageViewController.delegate = self
            self.pageViewController.view.isHidden = true
        
        case "showSettings":
            let destinationViewController = segue.destination
            destinationViewController.presentationController?.delegate = self
            
        default: break
        }
    }
    
    @IBAction private func unwindFromSettingsViewController(_ segue: UIStoryboardSegue)
    {
        self.sync()
    }
}

// MARK: - UI -
/// UI
private extension GamesViewController
{
    func prepareSearchController()
    {
        let searchResultsController = self.storyboard?.instantiateViewController(withIdentifier: "gameCollectionViewController") as! GameCollectionViewController
        searchResultsController.gameCollection = nil
        searchResultsController.fetchRequest = nil
        searchResultsController.customTitle = nil
        searchResultsController.theme = self.theme
        searchResultsController.activeEmulatorCore = self.activeEmulatorCore
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("No Games Found", comment: "")
        placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure the name is correct, or try searching for another game.", comment: "")
        
        switch self.theme
        {
        case .opaque: searchResultsController.dataSource.placeholderView = placeholderView
        case .translucent:
            let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
            vibrancyView.contentView.addSubview(placeholderView, pinningEdgesWith: .zero)
            searchResultsController.dataSource.placeholderView = vibrancyView
        }
        
        self.searchController = RSTSearchController(searchResultsController: searchResultsController)
        self.searchController?.searchableKeyPaths = [#keyPath(Game.name)]
        self.searchController?.searchHandler = { [weak self, weak searchResultsController] (searchValue, _) in
            guard let self = self else { return nil }
            
            if self.searchController?.searchBar.text?.isEmpty == false
            {
                self.pageViewController.view.isHidden = true
            }
            else
            {
                self.pageViewController.view.isHidden = false
            }
            
            searchResultsController?.dataSource.predicate = searchValue.predicate
            return nil
        }
        
        if #unavailable(iOS 26)
        {
            self.searchController?.searchBar.barStyle = .black
        }
        
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        
        self.definesPresentationContext = true
    }
    
    func updateTheme()
    {
        switch self.theme
        {
        case .opaque: self.view.backgroundColor = UIColor.deltaDarkGray
        case .translucent: self.view.backgroundColor = nil
        }
                
        if let viewControllers = self.pageViewController.viewControllers as? [GameCollectionViewController]
        {
            for collectionViewController in viewControllers
            {
                collectionViewController.theme = self.theme
            }
        }
    }
}

// MARK: - Helper Methods -
private extension GamesViewController
{
    func viewControllerForIndex(_ index: Int) -> GameCollectionViewController?
    {
        let pages = self.pages // Cache so we don't regenerate every time
        
        guard !pages.isEmpty else { return nil }
        
        // Return nil if only one section, and not asking for the 0th view controller
        guard !(pages.count == 1 && index != 0) else { return nil }
        
        var safeIndex = index % pages.count
        if safeIndex < 0
        {
            safeIndex = (pages.count + safeIndex)
        }
                
        let viewController = self.storyboard?.instantiateViewController(withIdentifier: "gameCollectionViewController") as! GameCollectionViewController
        
        let page = pages[safeIndex]
        viewController.page = page

        switch page
        {
        case .favorites:
            viewController.customTitle = NSLocalizedString("Favorites", comment: "")
            viewController.placeholderTitle = String(localized: "No Favorites")
            viewController.placeholderDescription = String(localized: "Long-press a game to add it to your favorites.")
            viewController.placeholderImage = UIImage(systemName: "star.fill")
            viewController.fetchRequest = Game.favoritesFetchRequest // Triggers placeholder build, so placeholder properties need to come first
        case .recentlyPlayed:
            viewController.customTitle = NSLocalizedString("Recently Played", comment: "")
            viewController.fetchRequest = Game.recentlyPlayedFetchRequest
        case .gameCollection(let gameCollection):
            viewController.gameCollection = gameCollection
        }
        
        viewController.theme = self.theme
        viewController.activeEmulatorCore = self.activeEmulatorCore
        
        return viewController
    }
    
    func updateSections(animated: Bool)
    {
        let hasRecentlyPlayed = self.recentlyPlayedFetchedResultsController.fetchedObjects?.count ?? 0 > 0
        self.hasRecentlyPlayed = hasRecentlyPlayed
        
        let sections = self.pages.count
        self.pageControl.model.indicators = self.pages.map { $0.pageIndicator }
        
        var resetPageViewController = false
        
        // Sync page control to whichever page is currently visible, or reset if page no longer exists
        if let viewController = self.pageViewController.viewControllers?.first as? GameCollectionViewController
        {
            if let page = viewController.page, let index = self.pages.firstIndex(of: page)
            {
                self.pageControl.model.currentPage = index
            }
            else
            {
                resetPageViewController = true
                self.pageControl.model.currentPage = min(1, self.pages.count - 1)
            }
        }
        
        if self.pageViewController.viewControllers?.count == 0
        {
            resetPageViewController = true
        }
        
        self.navigationController?.setToolbarHidden(sections < 2, animated: animated)
        self.pageControl.setHidden(sections < 2, animated: false)
        
        // Operator: show or hide cartridge status on empty placeholder
        self.updateOperatorPlaceholderVisibility(sectionCount: sections)

        if sections > 0
        {
            // Reset page view controller if currently hidden or current child should view controller no longer exists
            if self.pageViewController.view.isHidden || resetPageViewController
            {
                let index = min(1, self.pages.count - 1) // Recents page, or first game system
                
                if let viewController = self.viewControllerForIndex(index)
                {
                    self.pageViewController.view.setHidden(false, animated: animated)
                    self.pageViewController.view.superview?.setHidden(false, animated: animated)
                    self.placeholderView.setHidden(true, animated: animated)
                    
                    self.pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
                    
                    self.title = viewController.title
                    self.pageControl.model.currentPage = index
                }
            }
            else
            {
                self.pageViewController.setViewControllers(self.pageViewController.viewControllers, direction: .forward, animated: false, completion: nil)
            }
        }
        else
        {
            self.title = NSLocalizedString("Games", comment: "")
            
            self.pageViewController.view.setHidden(true, animated: animated)
            self.pageViewController.view.superview?.setHidden(true, animated: animated)
            self.placeholderView.setHidden(false, animated: animated)
        }
    }
    
    @objc func openFAQ()
    {
        let faqURL = URL(string: "https://faq.deltaemulator.com/getting-started/importing-games")!
        UIApplication.shared.open(faqURL)
    }
    
    @objc func resumeGame()
    {
        guard
            let gameCollectionViewController = self.pageViewController.viewControllers?.first as? GameCollectionViewController,
            let activeEmulatorCore = gameCollectionViewController.activeEmulatorCore,
            let game = activeEmulatorCore.game as? Game
        else { return }
        
        gameCollectionViewController.resume(game)
    }
}

//MARK: - Importing -
/// Importing
extension GamesViewController: ImportControllerDelegate
{
    private func makeImportController() -> ImportController
    {
        var documentTypes = Set(System.registeredSystems.map { $0.gameType.rawValue })
        documentTypes.insert(kUTTypeZipArchive as String)
        documentTypes.insert("com.rileytestut.delta.skin")
        
        #if BETA
        // .bin files (Genesis ROMs)
        documentTypes.insert("com.apple.macbinary-archive")
        #endif
        
        // Add GBA4iOS's exported UTIs in case user has GBA4iOS installed (which may override Delta's UTI declarations)
        documentTypes.insert("com.rileytestut.gba")
        documentTypes.insert("com.rileytestut.gbc")
        documentTypes.insert("com.rileytestut.gb")
        
        let importController = ImportController(documentTypes: documentTypes)
        importController.delegate = self
        
        return importController
    }
    
    @IBAction private func importFiles()
    {
        self.present(self.importController, animated: true, completion: nil)
    }
    
    func importController(_ importController: ImportController, didImportItemsAt urls: Set<URL>, errors: [Error])
    {
        for error in errors
        {
            print(error)
        }
        
        let gameURLs = urls.filter { $0.pathExtension.lowercased() != "deltaskin" }
        DatabaseManager.shared.importGames(at: Set(gameURLs)) { (games, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .games, with: errors)
                self.present(alertController, animated: true, completion: nil)
            }
            
            if games.count > 0
            {
                print("Imported Games:", games.map { $0.name })
            }
        }
        
        let controllerSkinURLs = urls.filter { $0.pathExtension.lowercased() == "deltaskin" }
        DatabaseManager.shared.importControllerSkins(at: Set(controllerSkinURLs)) { (controllerSkins, errors) in
            if errors.count > 0
            {
                let alertController = UIAlertController.alertController(for: .controllerSkins, with: errors)
                self.present(alertController, animated: true, completion: nil)
            }
            
            if controllerSkins.count > 0
            {
                print("Imported Controller Skins:", controllerSkins.map { $0.name })
            }
        }
    }
}

//MARK: - Syncing -
/// Syncing
private extension GamesViewController
{
    @IBAction func sync()
    {
        // Show toast view in case sync started before this view controller existed.
        self.showSyncingToastViewIfNeeded()
        
        SyncManager.shared.sync()
    }
    
    func showSyncingToastViewIfNeeded()
    {
        guard let coordinator = SyncManager.shared.coordinator, let syncProgress = SyncManager.shared.syncProgress, coordinator.isSyncing && self.syncingToastView == nil else { return }

        let toastView = RSTToastView(text: NSLocalizedString("Syncing...", comment: ""), detailText: syncProgress.localizedAdditionalDescription)
        toastView.activityIndicatorView.startAnimating()
        toastView.addTarget(self, action: #selector(GamesViewController.hideSyncingToastView), for: .touchUpInside)
        toastView.show(in: self.view)
        
        self.syncingProgressObservation = syncProgress.observe(\.localizedAdditionalDescription) { [weak toastView, weak self] (progress, change) in
            DispatchQueue.main.async {
                // Prevent us from updating text right as we're dismissing the toast view.
                guard self?.syncingToastView != nil else { return }
                toastView?.detailTextLabel.text = progress.localizedAdditionalDescription
            }
        }
        
        self.syncingToastView = toastView
    }
    
    func showSyncFinishedToastView(result: SyncResult)
    {
        let toastView: RSTToastView
        
        switch result
        {
        case .success: toastView = RSTToastView(text: NSLocalizedString("Sync Complete", comment: ""), detailText: nil)
        case .failure(let error): toastView = RSTToastView(text: NSLocalizedString("Sync Failed", comment: ""), detailText: error.failureReason)
        }
        
        toastView.textLabel.textAlignment = .center
        toastView.addTarget(self, action: #selector(GamesViewController.presentSyncResultsViewController), for: .touchUpInside)
        
        toastView.show(in: self.view, duration: 2.0)
        
        self.syncingToastView = nil
    }
    
    @objc func hideSyncingToastView()
    {
        self.syncingToastView = nil
    }
    
    @objc func presentSyncResultsViewController()
    {
        guard let result = SyncManager.shared.previousSyncResult else { return }
        
        let navigationController = SyncResultViewController.make(result: result)
        self.present(navigationController, animated: true, completion: nil)
    }
    
    func quitEmulation()
    {
        DispatchQueue.main.async {
            self.activeEmulatorCore = nil
            
            if let viewControllers = self.pageViewController.viewControllers as? [GameCollectionViewController]
            {
                for collectionViewController in viewControllers
                {
                    collectionViewController.activeEmulatorCore = nil
                }
            }
            
            self.theme = .opaque
        }
    }
}

//MARK: - Notifications -
/// Notifications
private extension GamesViewController
{
    @objc func managedObjectContextDidChange(with notification: Notification)
    {
        guard let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> else { return }
        
        if let game = self.activeEmulatorCore?.game as? Game
        {
            if deletedObjects.contains(game)
            {                
                self.quitEmulation()
            }
        }
        else
        {
            self.quitEmulation()
        }
    }
    
    @objc func syncingDidStart(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.showSyncingToastViewIfNeeded()
        }
    }
    
    @objc func syncingDidFinish(_ notification: Notification)
    {        
        DispatchQueue.main.async {
            guard let result = notification.userInfo?[SyncCoordinator.syncResultKey] as? SyncResult else { return }
            self.showSyncFinishedToastView(result: result)
        }
    }
    
    @objc func emulationDidQuit(_ notification: Notification)
    {
        guard let emulatorCore = notification.object as? EmulatorCore, emulatorCore == self.activeEmulatorCore else { return }
        self.quitEmulation()
    }
    
    @objc func settingsDidChange(_ notification: Notification)
    {
        guard let emulatorCore = self.activeEmulatorCore else { return }
        guard let game = emulatorCore.game as? Game else { return }
        
        game.managedObjectContext?.performAndWait {
            guard
                let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? String, name == Settings.preferredCoreSettingsKey(for: emulatorCore.game.type),
                let core = notification.userInfo?[Settings.NotificationUserInfoKey.core] as? DeltaCoreProtocol, core != emulatorCore.deltaCore
            else { return }
            
            emulatorCore.stop()
            self.quitEmulation()
        }
    }
    
    @objc func didFinishAuthenticatingAchievementsAccount(_ notification: Notification)
    {
        guard let result = notification.userInfo?[AchievementsManager.resultUserInfoKey] as? Result<AchievementsManager.Account, AchievementsError> else { return }
        
        DispatchQueue.main.async {
            let toastView: RSTToastView
            let duration: Double
            
            switch result
            {
            case .success(let account):
                if #available (iOS 26.0, *)
                {
                    let greetingView = AchievementToastView {
                        AchievementGreeting(account: account)
                    }
                    
                    // Delay for 0.5 seconds to give time to show page title on launch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        greetingView.show(in: self.navigationController?.view ?? self.view, duration: 4.0, useAutoLayout: false) // We shouldn't add constraints to views we don't control (i.e. navigation controller's view) or else Bad Things Might Happen™
                    }
                }
                else
                {
                    toastView = RSTToastView(text: String(format: NSLocalizedString("RetroAchievements: Logged in as “%@”", comment: ""), account.displayName), detailText: nil)
                    duration = 4.0
                    
                    toastView.presentationEdge = .top
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: duration)
                }
            case .failure(let error):
                toastView = RSTToastView(text: NSLocalizedString("Unable to Log In to RetroAchievements", comment: ""), detailText: error.localizedDescription)
                duration = 4.0
                
                toastView.presentationEdge = .top
                toastView.show(in: self.navigationController?.view ?? self.view, duration: duration)
            }
        }
    }
}

//MARK: - UIPageViewController -
/// UIPageViewController
extension GamesViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate
{
    //MARK: - UIPageViewControllerDataSource
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?
    {
        guard let gameCollectionVC = viewController as? GameCollectionViewController,
            let index = indexForViewController(gameCollectionVC) else { return nil }
        
        return self.viewControllerForIndex(index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        guard let gameCollectionVC = viewController as? GameCollectionViewController,
            let index = indexForViewController(gameCollectionVC) else { return nil }
        
        return self.viewControllerForIndex(index + 1)
    }
    
    func indexForViewController(_ viewController: GameCollectionViewController) -> Int?
    {
        guard let page = viewController.page else { return nil }
        return self.pages.firstIndex(of: page)
    }
    
    //MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
    {
        if let viewController = pageViewController.viewControllers?.first as? GameCollectionViewController,
           let page = viewController.page,
           let index = self.pages.firstIndex(of: page)
        {
            self.pageControl.model.currentPage = index

            if case .gameCollection(let collection) = page
            {
                Settings.previousGameCollection = collection
            }
            else
            {
                Settings.previousGameCollection = nil
            }
        }
        else { Settings.previousGameCollection = nil }
        
        self.title = pageViewController.viewControllers?.first?.title
    }
    
    // Fixes iOS 26 Navigation Bar by indicating correct scroll view
    override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView?
    {
        let viewController = self.pageViewController?.viewControllers?.first as? UICollectionViewController
        return viewController?.collectionView
    }
}

extension GamesViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController)
    {
        if searchController.searchBar.text?.isEmpty == false
        {            
            self.pageViewController.view.isHidden = true
        }
        else
        {
            self.pageViewController.view.isHidden = false
        }
    }
}

//MARK: - NSFetchedResultsControllerDelegate -
/// NSFetchedResultsControllerDelegate
extension GamesViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        self.updateSections(animated: true)
    }
}

extension GamesViewController: UIAdaptivePresentationControllerDelegate
{
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController)
    {
        self.sync()
    }
}
