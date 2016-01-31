//
//  GridCollectionViewLayout.swift
//  Delta
//
//  Created by Riley Testut on 10/24/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class GridCollectionViewLayout: UICollectionViewFlowLayout
{
    var itemWidth: CGFloat = 150 {
        didSet {
            // Only invalidate if needed, otherwise could potentially cause endless loop
            if oldValue != self.itemWidth
            {
                self.invalidateLayout()
            }
        }
    }
    
    // If only one row, distribute the items equally horizontally
    var usesEqualHorizontalSpacingDistributionForSingleRow = false
    
    override var estimatedItemSize: CGSize {
        didSet {
            fatalError("GridCollectionViewLayout does not support self-sizing cells.")
        }
    }
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]?
    {
        guard let collectionView = self.collectionView else { return nil }
        
        let maximumItemsPerRow = floor((collectionView.bounds.width - self.minimumInteritemSpacing) / (self.itemWidth + self.minimumInteritemSpacing))
        let interitemSpacing = (collectionView.bounds.width - maximumItemsPerRow * self.itemWidth) / (maximumItemsPerRow + 1)
        
        self.sectionInset.left = interitemSpacing
        self.sectionInset.right = interitemSpacing
        
        let layoutAttributes = super.layoutAttributesForElementsInRect(rect)?.map({ $0.copy() }) as! [UICollectionViewLayoutAttributes]
        
        var minimumY: CGFloat? = nil
        var maximumY: CGFloat? = nil
        var tempLayoutAttributes: [UICollectionViewLayoutAttributes] = []
        
        var isSingleRow = true
        
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
            
            if let maxY = maximumY, minY = minimumY
            {
                // If attributes.frame.minY is greater than maximumY, then it is a new row
                // In this case, we need to align all the previous tempLayoutAttributes to the same Y-value
                if attributes.frame.minY > maxY
                {
                    isSingleRow = false
                    
                    self.alignLayoutAttributes(tempLayoutAttributes, toMinimumY: minY)
                    
                    // Reset tempLayoutAttributes
                    tempLayoutAttributes.removeAll()
                    minimumY = nil
                    maximumY = nil
                }
            }
            
            // Update minimumY value if needed
            if minimumY == nil || attributes.frame.minY < minimumY!
            {
                minimumY = attributes.frame.minY
            }
            
            // Update maximumY value if needed
            if maximumY == nil || attributes.frame.maxY > maximumY!
            {
                maximumY = attributes.frame.maxY
            }
            
            tempLayoutAttributes.append(attributes)
        }
        
        // Handle the remaining tempLayoutAttributes
        if let minimumY = minimumY
        {
            self.alignLayoutAttributes(tempLayoutAttributes, toMinimumY: minimumY)
            
            if isSingleRow && self.usesEqualHorizontalSpacingDistributionForSingleRow
            {
                let spacing = (collectionView.bounds.width - (self.itemWidth * CGFloat(tempLayoutAttributes.count))) / (CGFloat(tempLayoutAttributes.count) + 1.0)
                
                for (index, layoutAttributes) in tempLayoutAttributes.enumerate()
                {
                    layoutAttributes.frame.origin.x = spacing + (spacing + self.itemWidth) * CGFloat(index)
                }
            }
        }
        
        return layoutAttributes
    }
    
}

private extension GridCollectionViewLayout
{
    func alignLayoutAttributes(layoutAttributes: [UICollectionViewLayoutAttributes], toMinimumY minimumY: CGFloat)
    {
        for attributes in layoutAttributes
        {
            attributes.frame.origin.y = minimumY
        }
    }
}
