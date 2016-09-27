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
    
    fileprivate let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
    
    var isTextLabelVibrancyEnabled = true {
        didSet {
            if self.isTextLabelVibrancyEnabled
            {
                self.vibrancyView.contentView.addSubview(self.textLabel)
            }
            else
            {
                self.addSubview(self.textLabel)
            }
        }
    }
    
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
        self.vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.vibrancyView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.addSubview(self.vibrancyView)
        
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textLabel.textColor = UIColor.white
        
        var fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3)
        fontDescriptor = fontDescriptor.withSymbolicTraits([.traitBold])!
        
        self.textLabel.font = UIFont(descriptor: fontDescriptor, size: 0.0)
        self.textLabel.textAlignment = .center
        self.vibrancyView.contentView.addSubview(self.textLabel)
        
        // Auto Layout
        self.textLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
        self.textLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20).isActive = true
        self.textLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
        self.textLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    }
}
