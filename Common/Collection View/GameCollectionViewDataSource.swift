//
//  GameCollectionViewDataSource.swift
//  Delta
//
//  Created by Riley Testut on 10/30/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

class GameCollectionViewDataSource: NSObject
{
    var supportedGameCollectionIdentifiers: [String]? {
        didSet
        {
            self.updateFetchedResultsController()
        }
    }
    
    var cellConfigurationHandler: ((GridCollectionViewCell, Game) -> Void)?
    
    private(set) var fetchedResultsController: NSFetchedResultsController = NSFetchedResultsController()
    
    private var prototypeCell = GridCollectionViewCell()
    
    private var _registeredCollectionViewCells = false
    
    // MARK: - Update -
    
    func update()
    {
        do
        {
            try self.fetchedResultsController.performFetch()
        }
        catch let error as NSError
        {
            print(error)
        }
    }
    
    private func updateFetchedResultsController()
    {
        let previousDelegate = self.fetchedResultsController.delegate
        
        let fetchRequest = Game.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let identifiers = self.supportedGameCollectionIdentifiers
        {
            for identifier in identifiers
            {
                let predicate = NSPredicate(format: "SUBQUERY(%K, $x, $x.%K == %@).@count > 0", GameAttributes.gameCollections.rawValue, GameCollectionAttributes.identifier.rawValue, identifier)
                predicates.append(predicate)
            }
        }
        
        if predicates.count > 0
        {
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: GameAttributes.typeIdentifier.rawValue, ascending: true), NSSortDescriptor(key: GameAttributes.name.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: GameAttributes.typeIdentifier.rawValue, cacheName: nil)
        self.fetchedResultsController.delegate = previousDelegate
        
        self.update()
    }
    
    // MARK: - Collection View -
    
    private func configureCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath)
    {
        let game = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Game
        
        if let handler = self.cellConfigurationHandler
        {
            handler(cell, game)
        }
    }
}

extension GameCollectionViewDataSource: UICollectionViewDataSource
{
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int
    {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let count = self.fetchedResultsController.sections?[section].numberOfObjects ?? 0
        return count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("GameCell", forIndexPath: indexPath) as! GridCollectionViewCell
        
        self.configureCell(cell, forIndexPath: indexPath)
        
        return cell
    }
}

extension GameCollectionViewDataSource: UICollectionViewDelegate
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        let collectionViewLayout = collectionView.collectionViewLayout as! GridCollectionViewLayout
        
        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(collectionViewLayout.itemWidth)
        widthConstraint.active = true
        
        self.configureCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        
        widthConstraint.active = false
        
        return size
    }
}
