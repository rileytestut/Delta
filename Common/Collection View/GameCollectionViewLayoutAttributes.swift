//
//  GameCollectionViewLayoutAttributes.swift
//  Delta
//
//  Created by Riley Testut on 10/28/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class GameCollectionViewLayoutAttributes: UICollectionViewLayoutAttributes
{
    var maximumBoxArtSize = CGSize(width: 100, height: 100)
    
    override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! GameCollectionViewLayoutAttributes
        copy.maximumBoxArtSize = self.maximumBoxArtSize
        
        return copy
    }
    
    override func isEqual(object: AnyObject?) -> Bool
    {
        guard super.isEqual(object) else { return false }
        guard let attributes = object as? GameCollectionViewLayoutAttributes else { return false }
        
        guard CGSizeEqualToSize(self.maximumBoxArtSize, attributes.maximumBoxArtSize) else { return false }
        
        return true
    }
}
