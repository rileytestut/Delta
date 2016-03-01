//
//  LoadImageOperation.swift
//  Delta
//
//  Created by Riley Testut on 2/26/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import ImageIO

public class LoadImageOperation: NSOperation
{
    public let URL: NSURL
    
    public var completionHandler: (UIImage? -> Void)?
    public var imageCache: NSCache?
    
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
        var image: UIImage?
        
        defer
        {
            if !self.cancelled
            {
                dispatch_async(dispatch_get_main_queue()) {
                    self.completionHandler?(image)
                }
            }
        }
        
        guard !self.cancelled else { return }
        
        if let cachedImage = self.imageCache?.objectForKey(self.URL) as? UIImage
        {
            image = cachedImage
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
            
            image = loadedImage
        }
    }
}