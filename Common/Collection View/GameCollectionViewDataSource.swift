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
    
    private(set) var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = NSFetchedResultsController<NSFetchRequestResult>()
    
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
        
        var predicates: [Predicate] = []
        
        if let identifiers = self.supportedGameCollectionIdentifiers
        {
            for identifier in identifiers
            {
                let predicate = Predicate(format: "SUBQUERY(%K, $x, $x.%K == %@).@count > 0", Game.Attributes.gameCollections.rawValue, GameCollection.Attributes.identifier.rawValue, identifier)
                predicates.append(predicate)
            }
        }
        
        if predicates.count > 0
        {
            fetchRequest.predicate = CompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
        
        fetchRequest.sortDescriptors = [SortDescriptor(key: Game.Attributes.typeIdentifier.rawValue, ascending: true), SortDescriptor(key: Game.Attributes.name.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: Game.Attributes.typeIdentifier.rawValue, cacheName: nil)
        self.fetchedResultsController.delegate = previousDelegate
        
        self.update()
    }
    
    // MARK: - Collection View -
    
    private func configureCell(_ cell: GridCollectionViewCell, forIndexPath indexPath: IndexPath)
    {
        let game = self.fetchedResultsController.object(at: indexPath) as! Game
        
        if let handler = self.cellConfigurationHandler
        {
            handler(cell, game)
        }
    }
}

extension GameCollectionViewDataSource: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let count = self.fetchedResultsController.sections?[section].numberOfObjects ?? 0
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GameCell", for: indexPath) as! GridCollectionViewCell
        
        self.configureCell(cell, forIndexPath: indexPath)
        
        return cell
    }
}

extension GameCollectionViewDataSource: UICollectionViewDelegate
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize
    {
        let collectionViewLayout = collectionView.collectionViewLayout as! GridCollectionViewLayout
        
        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionViewLayout.itemWidth)
        widthConstraint.isActive = true
        
        self.configureCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        
        widthConstraint.isActive = false
        
        return size
    }
}
