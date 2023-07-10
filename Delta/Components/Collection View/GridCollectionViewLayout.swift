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
    
    private var contentInset: UIEdgeInsets {
        guard let collectionView = self.collectionView else { return .zero }
        
        var contentInset = collectionView.contentInset
        contentInset.left += collectionView.safeAreaInsets.left
        contentInset.right += collectionView.safeAreaInsets.right
        
        return contentInset
    }
    
    private var contentWidth: CGFloat {
        guard let collectionView = self.collectionView else { return 0.0 }
        
        let contentWidth = collectionView.bounds.width - (self.contentInset.left + self.contentInset.right)
        return contentWidth
    }
    
    private var maximumItemsPerRow: Int {
        let maximumItemsPerRow = Int(floor((self.contentWidth - self.minimumInteritemSpacing) / (self.itemWidth + self.minimumInteritemSpacing)))
        return maximumItemsPerRow
    }
    
    private var interitemSpacing: CGFloat {
        let interitemSpacing = (self.contentWidth - CGFloat(self.maximumItemsPerRow) * self.itemWidth) / CGFloat(self.maximumItemsPerRow + 1)
        return interitemSpacing
    }
    
    private var cachedCellLayoutAttributes = [IndexPath: UICollectionViewLayoutAttributes]()
    
    override var estimatedItemSize: CGSize {
        didSet {
            fatalError("GridCollectionViewLayout does not support self-sizing cells.")
        }
    }
    
    override func prepare()
    {
        super.prepare()
        
        self.sectionInset.left = self.interitemSpacing + self.contentInset.left
        self.sectionInset.right = self.interitemSpacing + self.contentInset.right
    }
    
    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext)
    {
        super.invalidateLayout(with: context)
        
        if let context = context as? UICollectionViewFlowLayoutInvalidationContext,
            context.invalidateFlowLayoutAttributes || context.invalidateFlowLayoutDelegateMetrics || context.invalidateEverything
        {
            // Clear layout cache to prevent crashing due to returning outdated layout attributes.
            self.cachedCellLayoutAttributes = [:]
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
    {
        let layoutAttributes = super.layoutAttributesForElements(in: rect)?.map({ $0.copy() }) as! [UICollectionViewLayoutAttributes]
        
        var minimumY: CGFloat? = nil
        var maximumY: CGFloat? = nil
        var tempLayoutAttributes: [UICollectionViewLayoutAttributes] = []
        
        var isSingleRow = true
        
        for (index, attributes) in layoutAttributes.enumerated()
        {
            guard attributes.representedElementCategory == .cell else { continue }
            
            // Ensure equal spacing between items (that also match the section insets)
            if index > 0
            {
                let previousLayoutAttributes = layoutAttributes[index - 1]
                
                if abs(attributes.frame.minX - self.sectionInset.left) > 1
                {
                    attributes.frame.origin.x = previousLayoutAttributes.frame.maxX + self.interitemSpacing
                }
            }
            
            if let maxY = maximumY, let minY = minimumY
            {
                // If attributes.frame.minY is greater than maximumY, then it is a new row
                // In this case, we need to align all the previous tempLayoutAttributes to the same Y-value
                if attributes.frame.minY > maxY
                {
                    isSingleRow = false
                    
                    self.align(tempLayoutAttributes, toMinimumY: minY)
                    
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
            self.align(tempLayoutAttributes, toMinimumY: minimumY)
            
            if isSingleRow && self.usesEqualHorizontalSpacingDistributionForSingleRow
            {
                let spacing = (self.contentWidth - (self.itemWidth * CGFloat(tempLayoutAttributes.count))) / (CGFloat(tempLayoutAttributes.count) + 1.0)
                
                for (index, layoutAttributes) in tempLayoutAttributes.enumerated()
                {
                    layoutAttributes.frame.origin.x = spacing + (spacing + self.itemWidth) * CGFloat(index) + self.contentInset.left
                }
            }
        }
        
        for attributes in layoutAttributes where attributes.representedElementCategory == .cell
        {
            // Update cached attributes for layoutAttributesForItem(at:)
            self.cachedCellLayoutAttributes[attributes.indexPath] = attributes
        }
        
        return layoutAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes?
    {
        if let cachedAttributes = self.cachedCellLayoutAttributes[indexPath]
        {
            return cachedAttributes
        }
        
        return super.layoutAttributesForItem(at: indexPath)
    }
}

private extension GridCollectionViewLayout
{
    func align(_ layoutAttributes: [UICollectionViewLayoutAttributes], toMinimumY minimumY: CGFloat)
    {
        for attributes in layoutAttributes
        {
            attributes.frame.origin.y = minimumY
        }
    }
}
