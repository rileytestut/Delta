//
//  BoxArtImageView.swift
//  Delta
//
//  Created by Riley Testut on 10/27/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class BoxArtImageView: UIImageView
{
    override var image: UIImage? {
        didSet
        {
            if image == nil
            {
                image = UIImage(named: "BoxArt")
            }
            
        }
    }
    
    init()
    {
        super.init(image: nil)
        
        self.initialize()
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.image = nil
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        #if os(tvOS)
            self.adjustsImageWhenAncestorFocused = true
        #endif
        
        self.contentMode = .ScaleAspectFit
    }
}
