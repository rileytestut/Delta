//
//  LoadImageURLOperation.swift
//  Delta
//
//  Created by Riley Testut on 10/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import ImageIO

import SDWebImage

import Roxas

extension LoadImageURLOperation
{
    enum Error: Swift.Error
    {
        case doesNotExist
        case invalid
        case downloadFailed(Swift.Error)
    }
}

class LoadImageURLOperation: RSTLoadOperation<UIImage, NSURL>
{
    let url: URL
    
    override var isAsynchronous: Bool {
        return !self.url.isFileURL
    }
    
    private var downloadOperation: SDWebImageOperation?
    
    init(url: URL)
    {
        self.url = url
        
        super.init(cacheKey: url as NSURL)
    }
    
    override func cancel()
    {
        super.cancel()
        
        self.downloadOperation?.cancel()
        
        if self.isAsynchronous
        {
            self.finish()
        }
    }
    
    override func loadResult(completion: @escaping (UIImage?, Swift.Error?) -> Void)
    {
        let callback = { (image: UIImage?, error: Error?) in
            
            if let image = image, !self.isCancelled
            {
                // Force decompression of image
                UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1.0)
                image.draw(at: CGPoint.zero)
                UIGraphicsEndImageContext()
            }
            
            completion(image, error)
        }
        
        if self.url.isFileURL
        {
            self.loadLocalImage(completion: callback)
        }
        else
        {
            self.loadRemoteImage(completion: callback)
        }
    }
    
    private func loadLocalImage(completion: @escaping (UIImage?, Error?) -> Void)
    {
        guard let imageSource = CGImageSourceCreateWithURL(self.url as CFURL, nil) else {
            completion(nil, .doesNotExist)
            return
        }
        
        guard let quartzImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            completion(nil, .invalid)
            return
        }
        
        let image = UIImage(cgImage: quartzImage)
        completion(image, nil)
    }
    
    private func loadRemoteImage(completion: @escaping (UIImage?, Error?) -> Void)
    {
        let manager = SDWebImageManager.shared()
        
        self.downloadOperation = manager?.downloadImage(with: self.url, options: [.retryFailed, .continueInBackground], progress: nil, completed: { (image, error, cacheType, finished, imageURL) in
            if let error = error
            {
                completion(nil, .downloadFailed(error))
            }
            else
            {
                completion(image, nil)
            }
        })
    }
}
