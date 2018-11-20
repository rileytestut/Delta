//
//  BadgedTableViewCell.swift
//  Delta
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

class BadgedTableViewCell: UITableViewCell
{
    let badgeLabel = UILabel()
        
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
        self.badgeLabel.backgroundColor = .red
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
        contentSize.width += 10
        contentSize.height += 10
        contentSize.width = max(contentSize.width, contentSize.height)
        
        var frame = CGRect(x: self.contentView.bounds.maxX - contentSize.width,
                           y: self.contentView.bounds.midY - contentSize.height / 2,
                           width: contentSize.width,
                           height: contentSize.height)
        
        if self.accessoryType == .none
        {
            frame.origin.x -= spacing
        }
        
        self.badgeLabel.frame = frame
        self.badgeLabel.layer.cornerRadius = frame.height / 2
        
        self.badgeLabel.backgroundColor = .red
        
        let overlap = textLabel.frame.maxX - (frame.minX - spacing)
        if overlap > 0 && !self.badgeLabel.isHidden
        {
            textLabel.frame.size.width -= overlap
        }
    }
}
