//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import SNESDeltaCore

import Roxas

class GamesViewController: UIViewController
{
    private var pageViewController: UIPageViewController!
    private var backgroundView: RSTBackgroundView!
    private var pageControl: UIPageControl!
    
    private let fetchedResultsController: NSFetchedResultsController
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        fatalError("initWithNibName: not implemented")
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        let fetchRequest = GameCollection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: GameCollectionAttributes.index.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        super.init(coder: aDecoder)
        
        self.fetchedResultsController.delegate = self
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Games", comment: "")
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can import games by pressing the + button in the top right.", comment: "")
        self.view.insertSubview(self.backgroundView, atIndex: 0)
        
        self.pageViewController = self.childViewControllers.first as? UIPageViewController
        self.pageViewController.dataSource = self
        self.pageViewController.delegate = self
        self.pageViewController.view.hidden = true
        
        self.pageControl = UIPageControl()
        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.pageControl.hidesForSinglePage = false
        self.pageControl.numberOfPages = 3
        self.pageControl.currentPageIndicatorTintColor = UIColor.purpleColor()
        self.pageControl.pageIndicatorTintColor = UIColor.lightGrayColor()
        self.navigationController?.toolbar.addSubview(self.pageControl)
        
        self.pageControl.centerXAnchor.constraintEqualToAnchor(self.navigationController?.toolbar.centerXAnchor, constant: 0).active = true
        self.pageControl.centerYAnchor.constraintEqualToAnchor(self.navigationController?.toolbar.centerYAnchor, constant: 0).active = true
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
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
            
            self.updateSections()
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if let viewControllers = self.pageViewController.viewControllers as? [GamesCollectionViewController]
        {
            for viewController in viewControllers
            {
                viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Importing -
    
    @IBAction func importFiles()
    {
        let gamePickerController = GamePickerController()
        gamePickerController.delegate = self
        self.presentGamePickerController(gamePickerController, animated: true, completion: nil)
    }
    
    // MARK: - Navigation -
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let sourceViewController = segue.sourceViewController as? GamesCollectionViewController else { return }
        guard let destinationViewController = segue.destinationViewController as? EmulationViewController else { return }
        guard let cell = sender as? UICollectionViewCell else { return }
        
        let indexPath = sourceViewController.collectionView?.indexPathForCell(cell)
        let game = sourceViewController.dataSource.fetchedResultsController.objectAtIndexPath(indexPath!) as! Game
        
        destinationViewController.game = game
    }
}

private extension GamesViewController
{
    func viewControllerForIndex(index: Int) -> GamesCollectionViewController?
    {
        guard let pages = self.fetchedResultsController.sections?.first?.numberOfObjects where pages > 0 else { return nil }
        
        // Return nil if only one section, and not asking for the 0th view controller
        guard !(pages == 1 && index != 0) else { return nil }
        
        var safeIndex = index % pages
        if safeIndex < 0
        {
            safeIndex = pages + safeIndex
        }
        
        let indexPath = NSIndexPath(forRow: safeIndex, inSection: 0)
        
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("gamesCollectionViewController") as! GamesCollectionViewController
        viewController.gameCollection = self.fetchedResultsController.objectAtIndexPath(indexPath) as! GameCollection
        viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
        viewController.segueHandler = self
        
        return viewController
    }
    
    func updateSections()
    {
        let sections = self.fetchedResultsController.sections?.first?.numberOfObjects ?? 0
        self.pageControl.numberOfPages = sections
        
        var resetPageViewController = false
        
        if let viewController = pageViewController.viewControllers?.first as? GamesCollectionViewController, let gameCollection = viewController.gameCollection
        {
            if let index = self.fetchedResultsController.fetchedObjects?.indexOf({ $0 as! GameCollection == gameCollection })
            {
                self.pageControl.currentPage = index
            }
            else
            {
                resetPageViewController = true
                
                self.pageControl.currentPage = 0
            }
            
        }
        
        self.navigationController?.setToolbarHidden(sections < 2, animated: self.view.window != nil)
        
        if sections > 0
        {
            // Reset page view controller if currently hidden or current child should view controller no longer exists
            if self.pageViewController.view.hidden || resetPageViewController
            {
                if let viewController = self.viewControllerForIndex(0)
                {
                    self.pageViewController.view.hidden = false
                    self.backgroundView.hidden = true
                    
                    self.pageViewController.setViewControllers([viewController], direction: .Forward, animated: false, completion: nil)
                    
                    self.title = viewController.title
                }
            }
            else
            {
                self.pageViewController.setViewControllers(self.pageViewController.viewControllers, direction: .Forward, animated: false, completion: nil)
            }
        }
        else
        {
            self.title = NSLocalizedString("Games", comment: "")
            
            if !self.pageViewController.view.hidden
            {
                self.pageViewController.view.hidden = true
                self.backgroundView.hidden = false
            }
        }
    }
}

extension GamesViewController: GamePickerControllerDelegate
{
    func gamePickerController(gamePickerController: GamePickerController, didImportGames games: [Game])
    {
        print(games)
    }
}

extension GamesViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource
{
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController?
    {
        let viewController = self.viewControllerForIndex(self.pageControl.currentPage - 1)
        return viewController
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController?
    {
        let viewController = self.viewControllerForIndex(self.pageControl.currentPage + 1)
        return viewController
    }
    
    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool)
    {
        if let viewController = pageViewController.viewControllers?.first as? GamesCollectionViewController, let gameCollection = viewController.gameCollection
        {
            let index = self.fetchedResultsController.fetchedObjects?.indexOf({ $0 as! GameCollection == gameCollection }) ?? 0
            self.pageControl.currentPage = index
        }
        
        self.title = pageViewController.viewControllers?.first?.title
    }
}

extension GamesViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.updateSections()
    }
}
