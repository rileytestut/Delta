//
//  SaveStatesCollectionHeaderView.swift
//  Delta
//
//  Created by Riley Testut on 3/15/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class SaveStatesCollectionHeaderView: UICollectionReusableView
{
    let textLabel = UILabel()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textLabel.textColor = UIColor.whiteColor()
        
        var fontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleTitle3)
        fontDescriptor = fontDescriptor.fontDescriptorWithSymbolicTraits([.TraitBold])
        
        self.textLabel.font = UIFont(descriptor: fontDescriptor, size: 0.0)
        self.textLabel.textAlignment = .Center
        self.addSubview(self.textLabel)
        
        // Auto Layout
        NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-20-[textLabel]-20-|", options: [], metrics: nil, views: ["textLabel": self.textLabel]))
        NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-10-[textLabel]|", options: [], metrics: nil, views: ["textLabel": self.textLabel]))
    }
}
