//
//  LoadImageURLOperation.swift
//  Delta
//
//  Created by Riley Testut on 10/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import ImageIO

import Roxas

class LoadImageURLOperation: LoadImageOperation<NSURL>
{
    public let url: URL
    
    init(url: URL)
    {
        self.url = url
        super.init(cacheKey: url as NSURL)
    }
    
    override func loadImage() -> UIImage?
    {
        let options: NSDictionary = [kCGImageSourceShouldCache as NSString: true]
        
        guard let imageSource = CGImageSourceCreateWithURL(self.url as CFURL, options), let quartzImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options) else { return nil }
        
        let image = UIImage(cgImage: quartzImage)
        return image
    }
}
