//
//  BadgedTableViewCell.swift
//  Delta
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

extension BadgedTableViewCell
{
    enum Style
    {
        case pill
        case roundedRect
    }
}

class BadgedTableViewCell: UITableViewCell
{
    let badgeLabel = UILabel()
    
    var style: Style = .pill
        
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?)
    {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.badgeLabel.clipsToBounds = true
        self.badgeLabel.textAlignment = .center
        self.badgeLabel.backgroundColor = self.tintColor
        self.badgeLabel.font = UIFont.boldSystemFont(ofSize: 14)
        self.badgeLabel.textColor = .white
        self.contentView.addSubview(self.badgeLabel)
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        guard let textLabel = self.textLabel else { return }
        
        let spacing = 8 as CGFloat
        
        var contentSize = self.badgeLabel.intrinsicContentSize
        
        switch self.style
        {
        case .pill:
            contentSize.width += 10
            contentSize.height += 10
            
        case .roundedRect:
            contentSize.width += 16
            contentSize.height += 6
        }
        
        contentSize.width = max(contentSize.width, contentSize.height)
        
        let frame = CGRect(x: self.contentView.bounds.maxX - contentSize.width - spacing,
                           y: self.contentView.bounds.midY - contentSize.height / 2,
                           width: contentSize.width,
                           height: contentSize.height)
        self.badgeLabel.frame = frame
        
        switch self.style
        {
        case .pill: self.badgeLabel.layer.cornerRadius = frame.height / 2
        case .roundedRect: self.badgeLabel.layer.cornerRadius = frame.height / 3
        }
        
        let overlap = textLabel.frame.maxX - (frame.minX - spacing)
        if overlap > 0 && !self.badgeLabel.isHidden
        {
            textLabel.frame.size.width -= overlap
        }
    }
    
    override func tintColorDidChange()
    {
        super.tintColorDidChange()
        
        self.badgeLabel.backgroundColor = self.tintColor
    }
}
