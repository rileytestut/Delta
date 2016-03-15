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
    public let URL: NSURL
    
    public var completionHandler: (UIImage? -> Void)? {
        didSet {
            self.completionBlock = {
                rst_dispatch_sync_on_main_thread() {
                    self.completionHandler?(self.image)
                }
            }
        }
    }
    
    public var imageCache: NSCache? {
        didSet {
            // Ensures if an image is cached, it will be returned immediately, to prevent temporary flash of placeholder image
            self.immediate = self.imageCache?.objectForKey(self.URL) != nil
        }
    }
    
    private var image: UIImage?
    
    public init(URL: NSURL)
    {
        self.URL = URL
        
        super.init()
    }
}

public extension LoadImageOperation
{
    override func main()
    {
        guard !self.cancelled else { return }
        
        if let cachedImage = self.imageCache?.objectForKey(self.URL) as? UIImage
        {
            self.image = cachedImage
            return
        }
        
        let options: NSDictionary = [kCGImageSourceShouldCache as NSString: true]
        
        if let imageSource = CGImageSourceCreateWithURL(self.URL, options), quartzImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options)
        {
            let loadedImage = UIImage(CGImage: quartzImage)
            
            // Force decompression of image
            UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1.0)
            loadedImage.drawAtPoint(CGPoint.zero)
            UIGraphicsEndImageContext()
            
            self.imageCache?.setObject(loadedImage, forKey: self.URL)
            
            self.image = loadedImage
        }
    }
}