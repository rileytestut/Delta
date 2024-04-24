//
//  RoundedImageView.swift
//  Delta
//
//  Created by Riley Testut on 4/24/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

class RoundedImageView: UIView
{
    var shouldAlignBaselines = false
    
    var image: UIImage? {
        get { self.imageView.image }
        set {
            self.imageView.image = newValue
            self.setNeedsLayout()
        }
    }
    
    override var clipsToBounds: Bool {
        didSet {
            self.imageView.clipsToBounds = self.clipsToBounds
        }
    }
    
    override var contentMode: UIView.ContentMode {
        didSet {
            self.imageView.contentMode = self.contentMode
        }
    }
    
    private let imageView = UIImageView()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.clipsToBounds = true
        
        // Assign self.layer corner radius in case image is nil but background is non-nil.
        self.layer.cornerRadius = 5
        self.imageView.layer.cornerRadius = 5
        
        self.addSubview(self.imageView)
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        guard let image else { return }
        
        var aspectRatioFrame = AVMakeRect(aspectRatio: image.size, insideRect: self.bounds)
        
        if self.shouldAlignBaselines
        {
            aspectRatioFrame.origin.y = self.bounds.height - aspectRatioFrame.height
        }
        else
        {
            aspectRatioFrame.origin.y = self.bounds.midY - (aspectRatioFrame.height / 2)
        }
        
        self.imageView.frame = aspectRatioFrame
    }
}
