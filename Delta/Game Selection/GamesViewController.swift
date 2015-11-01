//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

import SNESDeltaCore

class GamesViewController: UIViewController
{
    var pageViewController: UIPageViewController! = nil
    
    let supportedGameTypeIdentifiers = [kUTTypeSNESGame as String]

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.pageViewController = self.childViewControllers.first as? UIPageViewController
        self.pageViewController.dataSource = self
        self.pageViewController.delegate = self
        
        let viewController = self.viewControllerForIndex(0)
        self.pageViewController.setViewControllers([viewController], direction: .Forward, animated: false, completion: nil)

        // Do any additional setup after loading the view.
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let viewController = self.pageViewController.viewControllers?.first as! GamesCollectionViewController
        viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
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
}

private extension GamesViewController
{
    func viewControllerForIndex(index: Int) -> GamesCollectionViewController
    {
        var safeIndex = index % self.supportedGameTypeIdentifiers.count
        if safeIndex < 0
        {
            safeIndex = self.supportedGameTypeIdentifiers.count + safeIndex
        }
                
        let viewController = self.storyboard?.instantiateViewControllerWithIdentifier("gamesCollectionViewController") as! GamesCollectionViewController
        viewController.gameTypeIdentifier = self.supportedGameTypeIdentifiers[safeIndex] as String
        viewController.collectionView?.contentInset.top = self.topLayoutGuide.length
        
        return viewController
    }
}

extension GamesViewController: GamePickerControllerDelegate
{
    func gamePickerController(gamePickerController: GamePickerController, didImportGames games: [Game])
    {
        DatabaseManager.sharedManager.save()
        print(games)
    }
}

extension GamesViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource
{
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController?
    {
        let index = self.supportedGameTypeIdentifiers.indexOf((viewController as! GamesCollectionViewController).gameTypeIdentifier)
        let viewController = self.viewControllerForIndex(index! - 1)
        return viewController
    }
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController?
    {
        let index = self.supportedGameTypeIdentifiers.indexOf((viewController as! GamesCollectionViewController).gameTypeIdentifier)
        let viewController = self.viewControllerForIndex(index! + 1)
        return viewController
    }
}
