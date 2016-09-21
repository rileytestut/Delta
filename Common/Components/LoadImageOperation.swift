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

public class LoadImageOperation: RSTOperation
{
    public let URL: Foundation.URL
    
    public var completionHandler: ((UIImage?) -> Void)? {
        didSet {
            self.completionBlock = {
                rst_dispatch_sync_on_main_thread() {
                    self.completionHandler?(self.image)
                }
            }
        }
    }
    
    public var imageCache: NSCache<NSURL, UIImage>? {
        didSet {
            // Ensures if an image is cached, it will be returned immediately, to prevent temporary flash of placeholder image
            self.isImmediate = self.imageCache?.object(forKey: self.URL as NSURL) != nil
        }
    }
    
    fileprivate var image: UIImage?
    
    public init(URL: Foundation.URL)
    {
        self.URL = URL
        
        super.init()
    }
}

public extension LoadImageOperation
{
    override public func main()
    {
        guard !self.isCancelled else { return }
        
        if let cachedImage = self.imageCache?.object(forKey: self.URL as NSURL)
        {
            self.image = cachedImage
            return
        }
        
        let options: NSDictionary = [kCGImageSourceShouldCache as NSString: true]
        
        if let imageSource = CGImageSourceCreateWithURL(self.URL as CFURL, options), let quartzImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options)
        {
            let loadedImage = UIImage(cgImage: quartzImage)
            
            // Force decompression of image
            UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1.0)
            loadedImage.draw(at: CGPoint.zero)
            UIGraphicsEndImageContext()
            
            self.imageCache?.setObject(loadedImage, forKey: self.URL as NSURL)
            
            self.image = loadedImage
        }
    }
}
