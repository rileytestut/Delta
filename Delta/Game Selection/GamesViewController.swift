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

class GamesViewController: UIViewController
{
    var theme: Theme = .opaque {
        didSet {
            self.updateTheme()
        }
    }
    
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private var pageViewController: UIPageViewController!
    private var placeholderView: RSTPlaceholderView!
    private var pageControl: UIPageControl!
    
    private let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
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
        
        super.init(coder: aDecoder)
        
        self.fetchedResultsController.delegate = self
        
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
        
        self.pageControl = UIPageControl()
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.pageControl.hidesForSinglePage = false
        self.pageControl.currentPageIndicatorTintColor = UIColor.deltaPurple
        self.pageControl.pageIndicatorTintColor = UIColor.lightGray
        self.pageControl.addTarget(self, action: #selector(pageControlValueChanged(_:)), for: .valueChanged)
        self.navigationController?.toolbar.addSubview(self.pageControl)
        
        self.pageControl.centerXAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerXAnchor)!, constant: 0).isActive = true
        self.pageControl.centerYAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerYAnchor)!, constant: 0).isActive = true
        
        if #available(iOS 16, *)
        {
            let resumeButton = UIBarButtonItem(title: NSLocalizedString("Resume", comment: ""), style: .done, target: self, action: #selector(GamesViewController.resumeGame))
            resumeButton.isHidden = true
            self.resumeButton = resumeButton
            
            self.setToolbarItems([.flexibleSpace(), resumeButton], animated: false)
        }
        
        if let navigationController = self.navigationController
        {
            if #available(iOS 13.0, *)
            {
                navigationController.overrideUserInterfaceStyle = .dark
                
                let navigationBarAppearance = navigationController.navigationBar.standardAppearance.copy()
                navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .dark)
                navigationController.navigationBar.standardAppearance = navigationBarAppearance
                navigationController.navigationBar.scrollEdgeAppearance = navigationBarAppearance
                
                let toolbarAppearance = navigationController.toolbar.standardAppearance.copy()
                toolbarAppearance.backgroundEffect = UIBlurEffect(style: .dark)
                navigationController.toolbar.standardAppearance = toolbarAppearance
                
                if #available(iOS 15, *)
                {
                    navigationController.toolbar.scrollEdgeAppearance = toolbarAppearance
                }
            }
            else
            {
                navigationController.navigationBar.barStyle = .blackTranslucent
                navigationController.toolbar.barStyle = .blackTranslucent
            }            
        }
        
        if #available(iOS 14, *)
        {
            self.importController.presentingViewController = self
            
            let importActions = self.importController.makeActions().menuActions
            let importMenu = UIMenu(title: NSLocalizedString("Import From…", comment: ""), image: UIImage(systemName: "square.and.arrow.down"), children: importActions)
            self.importButton.menu = importMenu

            self.importButton.action = nil
            self.importButton.target = nil
        }
        else
        {
            self.importController.barButtonItem = self.importButton
        }
        
        self.navigationItem.leftBarButtonItem?.accessibilityLabel = NSLocalizedString("Settings", comment: "")
        
        self.prepareSearchController()
        
        self.updateTheme()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if self.fetchedResultsController.performFetchIfNeeded()
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
        
        if !UserDefaults.standard.didShowWhatsNew
        {
            self.performSegue(withIdentifier: "showWhatsNew", sender: nil)
            UserDefaults.standard.didShowWhatsNew = true
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
        self.searchController?.searchBar.barStyle = .black
        
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

// MARK: - Actions -
private extension GamesViewController
{
    @objc func pageControlValueChanged(_ sender: UIPageControl)
    {
        guard let destinationViewController = viewControllerForIndex(sender.currentPage) else { return }
        pageViewController.setViewControllers([destinationViewController], direction: .forward, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.pageViewController(self.pageViewController, didFinishAnimating: true, previousViewControllers: [destinationViewController], transitionCompleted: true)
        }
    }
}

// MARK: - Helper Methods -
private extension GamesViewController
{
    func viewControllerForIndex(_ index: Int) -> GameCollectionViewController?
    {
        guard let pages = self.fetchedResultsController.sections?.first?.numberOfObjects, pages > 0 else { return nil }
        
        // Return nil if only one section, and not asking for the 0th view controller
        guard !(pages == 1 && index != 0) else { return nil }
        
        var safeIndex = index % pages
        if safeIndex < 0
        {
            safeIndex = pages + safeIndex
        }
        
        let indexPath = IndexPath(row: safeIndex, section: 0)
        
        let viewController = self.storyboard?.instantiateViewController(withIdentifier: "gameCollectionViewController") as! GameCollectionViewController
        viewController.gameCollection = self.fetchedResultsController.object(at: indexPath) as? GameCollection
        viewController.theme = self.theme
        viewController.activeEmulatorCore = self.activeEmulatorCore
        
        return viewController
    }
    
    func updateSections(animated: Bool)
    {
        let sections = self.fetchedResultsController.sections?.first?.numberOfObjects ?? 0
        self.pageControl.numberOfPages = sections
        
        var resetPageViewController = false
        
        if let viewController = self.pageViewController.viewControllers?.first as? GameCollectionViewController, let gameCollection = viewController.gameCollection
        {
            if let index = self.fetchedResultsController.fetchedObjects?.firstIndex(where: { $0 as! GameCollection == gameCollection })
            {
                self.pageControl.currentPage = index
            }
            else
            {
                resetPageViewController = true
                
                self.pageControl.currentPage = 0
            }
            
        }
        
        if self.pageViewController.viewControllers?.count == 0
        {
            resetPageViewController = true
        }
        
        self.navigationController?.setToolbarHidden(sections < 2, animated: animated)
        
        if sections > 0
        {
            // Reset page view controller if currently hidden or current child should view controller no longer exists
            if self.pageViewController.view.isHidden || resetPageViewController
            {
                var index = 0
                
                if let gameCollection = Settings.previousGameCollection
                {
                    if let gameCollectionIndex = self.fetchedResultsController.fetchedObjects?.firstIndex(where: { $0 as! GameCollection == gameCollection })
                    {
                        index = gameCollectionIndex
                    }
                }
                
                if let viewController = self.viewControllerForIndex(index)
                {
                    self.pageViewController.view.setHidden(false, animated: animated)
                    self.pageViewController.view.superview?.setHidden(false, animated: animated)
                    self.placeholderView.setHidden(true, animated: animated)
                    
                    self.pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
                    
                    self.title = viewController.title
                    self.pageControl.currentPage = index
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
        
        let itunesImportOption = iTunesImportOption(presentingViewController: self)
        
        let importController = ImportController(documentTypes: documentTypes)
        importController.delegate = self
        importController.importOptions = [itunesImportOption]
        
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
                toastView = RSTToastView(text: String(format: NSLocalizedString("RetroAchievements: Logged in as “%@”", comment: ""), account.displayName), detailText: nil)
                duration = 4.0
                
            case .failure(let error):
                toastView = RSTToastView(text: NSLocalizedString("Unable to Log In to RetroAchievements", comment: ""), detailText: error.localizedDescription)
                duration = 4.0
            }
            
            toastView.presentationEdge = .top
            toastView.show(in: self.navigationController?.view ?? self.view, duration: duration)
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
        let viewController = self.viewControllerForIndex(self.pageControl.currentPage - 1)
        return viewController
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
        let viewController = self.viewControllerForIndex(self.pageControl.currentPage + 1)
        return viewController
    }
    
    //MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
    {
        if let viewController = pageViewController.viewControllers?.first as? GameCollectionViewController, let gameCollection = viewController.gameCollection
        {
            let index = self.fetchedResultsController.fetchedObjects?.firstIndex(where: { $0 as! GameCollection == gameCollection }) ?? 0
            self.pageControl.currentPage = index
            
            Settings.previousGameCollection = gameCollection
        }
        else
        {
            Settings.previousGameCollection = nil
        }
        
        self.title = pageViewController.viewControllers?.first?.title
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
