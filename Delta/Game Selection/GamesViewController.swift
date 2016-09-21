//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore

import Roxas

extension GamesViewController
{
    enum Theme
    {
        case light
        case dark
    }
}

class GamesViewController: UIViewController
{
    var theme: Theme = .light {
        didSet {
            self.updateTheme()
        }
    }
    
    weak var activeEmulatorCore: EmulatorCore?
    
    fileprivate var pageViewController: UIPageViewController!
    fileprivate var backgroundView: RSTBackgroundView!
    fileprivate var pageControl: UIPageControl!
    
    fileprivate let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
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
        
        self.automaticallyAdjustsScrollViewInsets = false
    }
}

//MARK: - UIViewController -
/// UIViewController
extension GamesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Games", comment: "")
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can import games by pressing the + button in the top right.", comment: "")
        self.view.insertSubview(self.backgroundView, at: 0)
        
        self.pageControl = UIPageControl()
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.pageControl.hidesForSinglePage = false
        self.pageControl.numberOfPages = 3
        self.pageControl.currentPageIndicatorTintColor = UIColor.deltaPurpleColor()
        self.pageControl.pageIndicatorTintColor = UIColor.lightGray
        self.navigationController?.toolbar.addSubview(self.pageControl)
        
        self.pageControl.centerXAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerXAnchor)!, constant: 0).isActive = true
        self.pageControl.centerYAnchor.constraint(equalTo: (self.navigationController?.toolbar.centerYAnchor)!, constant: 0).isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if self.fetchedResultsController.performFetchIfNeeded()
        {
            self.updateSections(animated: false)
        }
        
        DispatchQueue.global().async {
            self.activeEmulatorCore?.stop()
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if let viewControllers = self.pageViewController.viewControllers as? [GameCollectionViewController]
        {
            for viewController in viewControllers
            {
                viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
            }
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
        guard let identifier = segue.identifier, identifier == "embedPageViewController" else { return }
        
        self.pageViewController = segue.destination as! UIPageViewController
        self.pageViewController.dataSource = self
        self.pageViewController.delegate = self
        self.pageViewController.view.isHidden = true
    }
    
    @IBAction private func unwindFromSettingsViewController(_ segue: UIStoryboardSegue)
    {
    }
}

// MARK: - UI -
/// UI
private extension GamesViewController
{
    func updateTheme()
    {
        switch self.theme
        {
        case .light:
            self.view.backgroundColor = UIColor.white
            self.navigationController?.navigationBar.barStyle = .default
            self.navigationController?.toolbar.barStyle = .default
            
        case .dark:
            self.view.backgroundColor = nil
            self.navigationController?.navigationBar.barStyle = .blackTranslucent
            self.navigationController?.toolbar.barStyle = .blackTranslucent
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
        viewController.gameCollection = self.fetchedResultsController.object(at: indexPath) as! GameCollection
        viewController.theme = self.theme
        viewController.activeEmulatorCore = self.activeEmulatorCore
        
        // Need to set content inset here AND willTransitionTo callback to ensure its correct for all edge cases
        viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
        
        return viewController
    }
    
    func updateSections(animated: Bool)
    {
        let sections = self.fetchedResultsController.sections?.first?.numberOfObjects ?? 0
        self.pageControl.numberOfPages = sections
        
        var resetPageViewController = false
        
        if let viewController = pageViewController.viewControllers?.first as? GameCollectionViewController, let gameCollection = viewController.gameCollection
        {
            if let index = self.fetchedResultsController.fetchedObjects?.index(where: { $0 as! GameCollection == gameCollection })
            {
                self.pageControl.currentPage = index
            }
            else
            {
                resetPageViewController = true
                
                self.pageControl.currentPage = 0
            }
            
        }
        
        self.navigationController?.setToolbarHidden(sections < 2, animated: animated)
        
        if sections > 0
        {
            // Reset page view controller if currently hidden or current child should view controller no longer exists
            if self.pageViewController.view.isHidden || resetPageViewController
            {
                if let viewController = self.viewControllerForIndex(0)
                {
                    self.pageViewController.view.setHidden(false, animated: animated)
                    self.backgroundView.setHidden(true, animated: animated)
                    
                    self.pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
                    
                    self.title = viewController.title
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
            self.backgroundView.setHidden(false, animated: animated)
        }
    }
}

//MARK: - Importing -
/// Importing
extension GamesViewController: GamePickerControllerDelegate
{
    @IBAction fileprivate func importFiles()
    {
        let gamePickerController = GamePickerController()
        gamePickerController.delegate = self
        self.presentGamePickerController(gamePickerController, animated: true, completion: nil)
    }
    
    //MARK: - GamePickerControllerDelegate
    func gamePickerController(_ gamePickerController: GamePickerController, didImportGames games: [Game])
    {
        print(games)
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
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController])
    {
        guard let viewControllers = pendingViewControllers as? [GameCollectionViewController] else { return }
        
        for viewController in viewControllers
        {
            viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
    {
        if let viewController = pageViewController.viewControllers?.first as? GameCollectionViewController, let gameCollection = viewController.gameCollection
        {
            let index = self.fetchedResultsController.fetchedObjects?.index(where: { $0 as! GameCollection == gameCollection }) ?? 0
            self.pageControl.currentPage = index
        }
        
        self.title = pageViewController.viewControllers?.first?.title
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
