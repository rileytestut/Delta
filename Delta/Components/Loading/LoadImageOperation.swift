//
//  LoadImageOperation.swift
//  Delta
//
//  Created by Riley Testut on 2/26/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import ImageIO

import Roxas

class LoadImageOperation<CacheKeyType: AnyObject>: RSTOperation
{
    var completionHandler: ((UIImage?) -> Void)? {
        didSet {
            self.completionBlock = {
                rst_dispatch_sync_on_main_thread() {
                    self.completionHandler?(self.image)
                }
            }
        }
    }
    
    var imageCache: NSCache<CacheKeyType, UIImage>? {
        didSet {
            // Ensures if an image is cached, it will be returned immediately, to prevent temporary flash of placeholder image
            self.isImmediate = self.imageCache?.object(forKey: self.cacheKey) != nil
        }
    }
    
    private let cacheKey: CacheKeyType
    private var image: UIImage?
    
    init(cacheKey: CacheKeyType)
    {
        self.cacheKey = cacheKey
        
        super.init()
    }
    
    override func main()
    {
        guard !self.isCancelled else { return }
        
        if let cachedImage = self.imageCache?.object(forKey: self.cacheKey)
        {
            self.image = cachedImage
            return
        }
        
        guard let loadedImage = self.loadImage() else { return }
        
        // Force decompression of image
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1.0)
        loadedImage.draw(at: CGPoint.zero)
        UIGraphicsEndImageContext()
        
        self.imageCache?.setObject(loadedImage, forKey: self.cacheKey)
        
        self.image = loadedImage
    }
    
    func loadImage() -> UIImage?
    {
        return nil
    }
}
