//
//  GameCollectionViewLayout.swift
//  Delta
//
//  Created by Riley Testut on 10/24/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class GameCollectionViewLayout: UICollectionViewFlowLayout
{
    var maximumBoxArtSize = CGSize(width: 100, height: 100) {
        didSet
        {
            self.invalidateLayout()
        }
    }
    
    override class func layoutAttributesClass() -> AnyClass
    {
        return GameCollectionViewLayoutAttributes.self
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes?
    {
        // Need to implement this method as well in case the view controller calls it (which it does)
        
        let layoutAttributes = super.layoutAttributesForItemAtIndexPath(indexPath)?.copy() as! GameCollectionViewLayoutAttributes
        self.configureLayoutAttributes(layoutAttributes)
        
        return layoutAttributes
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]?
    {
        guard let collectionView = self.collectionView else { return nil }
        
        let maximumItemsPerRow = floor((collectionView.bounds.width - self.minimumInteritemSpacing) / (self.maximumBoxArtSize.width + self.minimumInteritemSpacing))
        let interitemSpacing = (collectionView.bounds.width - maximumItemsPerRow * self.maximumBoxArtSize.width) / (maximumItemsPerRow + 1)
        
        self.sectionInset = UIEdgeInsets(top: interitemSpacing, left: interitemSpacing, bottom: interitemSpacing, right: interitemSpacing)
        
        let layoutAttributes = super.layoutAttributesForElementsInRect(rect)?.map({ $0.copy() }) as! [GameCollectionViewLayoutAttributes]
        
        var minimumY: CGFloat? = nil
        var maximumY: CGFloat? = nil
        var tempLayoutAttributes: [GameCollectionViewLayoutAttributes] = []
        
        for (index, attributes) in layoutAttributes.enumerate()
        {            
            // Ensure equal spacing between items (that also match the section insets)
            if index > 0
            {                
                let previousLayoutAttributes = layoutAttributes[index - 1]
                
                if abs(attributes.frame.minX - self.sectionInset.left) > 1
                {
                    attributes.frame.origin.x = previousLayoutAttributes.frame.maxX + interitemSpacing
                }
            }
            
            self.configureLayoutAttributes(attributes)
            
            if let maxY = maximumY, minY = minimumY
            {
                // If attributes.frame.minY is greater than maximumY, then it is a new row
                // In this case, we need to align all the previous tempLayoutAttributes to the same Y-value
                if attributes.frame.minY > maxY
                {
                    for tempAttributes in tempLayoutAttributes
                    {
                        tempAttributes.frame.origin.y = minY
                    }
                    
                    // Reset tempLayoutAttributes
                    tempLayoutAttributes.removeAll()
                    minimumY = nil
                    maximumY = nil
                }
            }
            
            if minimumY == nil || attributes.frame.minY < minimumY!
            {
                minimumY = attributes.frame.minY
            }
            
            if maximumY == nil || attributes.frame.maxY > maximumY!
            {
                maximumY = attributes.frame.maxY
            }
            
            tempLayoutAttributes.append(attributes)
        }
        
        // Handle the remaining tempLayoutAttributes
        if let minimumY = minimumY
        {
            for tempAttributes in tempLayoutAttributes
            {
                tempAttributes.frame.origin.y = minimumY
            }
        }

        return layoutAttributes
    }
    
    // You'd think you could just do this in layoutAttributesForItemAtIndexPath, but alas layoutAttributesForElementsInRect does not call that method :(
    private func configureLayoutAttributes(layoutAttributes: GameCollectionViewLayoutAttributes)
    {
        layoutAttributes.maximumBoxArtSize = self.maximumBoxArtSize
    }
}
