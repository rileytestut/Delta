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
    let textView = UITextView()
    
    private let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
    
    var isTextVibrancyEnabled = true {
        didSet {
            if self.isTextVibrancyEnabled
            {
                self.vibrancyView.contentView.addSubview(self.textView)
            }
            else
            {
                self.addSubview(self.textView)
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
        
        self.textView.delegate = self
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.textContainer.lineFragmentPadding = 0
        self.textView.textContainerInset = .zero
        self.textView.isSelectable = true // Must be true to open links
        self.textView.isEditable = false
        self.textView.isScrollEnabled = false
        self.textView.backgroundColor = nil
        self.addSubview(self.textView)
        
        // Auto Layout
        self.textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
        self.textView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20).isActive = true
        self.textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 10).isActive = true
        self.textView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        
        self.reset()
    }
    
    override func prepareForReuse() 
    {
        super.prepareForReuse()
        
        self.reset()
    }
    
    private func reset()
    {
        self.textView.attributedText = nil
        
        var fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3)
        fontDescriptor = fontDescriptor.withSymbolicTraits([.traitBold])!
        
        self.textView.font = UIFont(descriptor: fontDescriptor, size: 0.0)
        self.textView.textAlignment = .center
        self.textView.textColor = UIColor.white
        self.textView.textContainer.lineBreakMode = .byWordWrapping
    }
}

extension SaveStatesCollectionHeaderView: UITextViewDelegate
{
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
    {
        return true
    }
}
