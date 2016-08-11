//
//  GamesCollectionViewController.swift
//  Delta
//
//  Created by Riley Testut on 10/12/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore

class GamesCollectionViewController: UICollectionViewController
{
    var theme: GamesViewController.Theme = .light {
        didSet {
            self.collectionView?.reloadData()
        }
    }
    
    weak var segueHandler: UIViewController?
    
    var gameCollection: GameCollection! {
        didSet
        {
            self.dataSource.supportedGameCollectionIdentifiers = [self.gameCollection.identifier]
            self.title = self.gameCollection.shortName
        }
    }
    
    let dataSource = GameCollectionViewDataSource()
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.dataSource.fetchedResultsController.delegate = self
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, game) in
            self.configureCell(cell, game: game)
        }
    }
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.dataSource = self.dataSource
        self.collectionView?.delegate = self.dataSource
        
        if let layout = self.collectionViewLayout as? GridCollectionViewLayout
        {
            layout.itemWidth = 90
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        self.dataSource.update()
        
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation -
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        self.segueHandler?.prepare(for: segue, sender: sender)
    }
    
    // MARK: - Collection View -
    
    private func configureCell(_ cell: GridCollectionViewCell, game: Game)
    {
        cell.maximumImageSize = CGSize(width: 90, height: 90)
        cell.textLabel.text = game.name
        cell.imageView.image = UIImage(named: "BoxArt")
        
        switch self.theme
        {
        case .light:
            cell.textLabel.textColor = UIColor.darkText
            cell.isTextLabelVibrancyEnabled = false
            cell.isImageViewVibrancyEnabled = false
            
        case .dark:
            cell.textLabel.textColor = UIColor.white
            cell.isTextLabelVibrancyEnabled = true
            cell.isImageViewVibrancyEnabled = true
        }
    }
}

extension GamesCollectionViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        self.collectionView?.reloadData()
    }
}
