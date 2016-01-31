//
//  GridCollectionViewCell.swift
//  Delta
//
//  Created by Riley Testut on 10/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class GridCollectionViewCell: UICollectionViewCell
{
    let imageView = UIImageView()
    let textLabel = UILabel()
    
    var maximumImageSize: CGSize = CGSize(width: 100, height: 100) {
        didSet {
            self.updateMaximumImageSize()
        }
    }
    
    private var imageViewWidthConstraint: NSLayoutConstraint!
    private var imageViewHeightConstraint: NSLayoutConstraint!
    
    private var textLabelBottomAnchorConstraint: NSLayoutConstraint!
    
    private var textLabelVerticalSpacingConstraint: NSLayoutConstraint!
    private var textLabelFocusedVerticalSpacingConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.configureSubviews()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.configureSubviews()
    }
    
    private func configureSubviews()
    {
        // Fix super annoying Unsatisfiable Constraints message in debugger by setting autoresizingMask
        self.contentView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.contentMode = .ScaleAspectFit
        #if os(tvOS)
            self.imageView.adjustsImageWhenAncestorFocused = true
        #endif
        self.contentView.addSubview(self.imageView)
        
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textLabel.font = UIFont.boldSystemFontOfSize(12)
        self.textLabel.textAlignment = .Center
        self.textLabel.numberOfLines = 0
        self.contentView.addSubview(self.textLabel)
        
        // Auto Layout
        
        self.imageView.topAnchor.constraintEqualToAnchor(self.contentView.topAnchor).active = true
        self.imageView.centerXAnchor.constraintEqualToAnchor(self.contentView.centerXAnchor).active = true
        
        self.imageViewWidthConstraint = self.imageView.widthAnchor.constraintEqualToConstant(self.maximumImageSize.width)
        self.imageViewWidthConstraint.active = true
        
        self.imageViewHeightConstraint = self.imageView.heightAnchor.constraintEqualToConstant(self.maximumImageSize.height)
        self.imageViewHeightConstraint.active = true
        
        
        self.textLabel.trailingAnchor.constraintEqualToAnchor(self.contentView.trailingAnchor).active = true
        self.textLabel.leadingAnchor.constraintEqualToAnchor(self.contentView.leadingAnchor).active = true
        
        self.textLabelBottomAnchorConstraint = self.textLabel.bottomAnchor.constraintEqualToAnchor(self.contentView.bottomAnchor)
        self.textLabelBottomAnchorConstraint.active = true
        
        self.textLabelVerticalSpacingConstraint = self.textLabel.topAnchor.constraintEqualToAnchor(self.imageView.bottomAnchor)
        self.textLabelVerticalSpacingConstraint.active = true
        
        
        #if os(tvOS)
            self.textLabelVerticalSpacingConstraint.active = false
            
            self.textLabelFocusedVerticalSpacingConstraint = self.textLabel.topAnchor.constraintEqualToAnchor(self.imageView.focusedFrameGuide.bottomAnchor, constant: 0)
            self.textLabelFocusedVerticalSpacingConstraint?.active = true
        #else
            self.textLabelVerticalSpacingConstraint.active = true
        #endif
        
        
        self.updateMaximumImageSize()
    }

    override func didUpdateFocusInContext(context: UIFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator)
    {
        super.didUpdateFocusInContext(context, withAnimationCoordinator: coordinator)
        
        coordinator.addCoordinatedAnimations({
            
            if context.nextFocusedView == self
            {
                self.textLabelBottomAnchorConstraint?.active = false
                self.textLabelVerticalSpacingConstraint.active = false
                
                self.textLabelFocusedVerticalSpacingConstraint?.active = true
                
                self.textLabel.textColor = UIColor.whiteColor()
                
            }
            else
            {
                self.textLabelFocusedVerticalSpacingConstraint?.active = false
                
                self.textLabelBottomAnchorConstraint?.active = true
                self.textLabelVerticalSpacingConstraint.active = true
                
                self.textLabel.textColor = UIColor.blackColor()
            }
            
            self.layoutIfNeeded()
            
        }, completion: nil)
    }
}

private extension GridCollectionViewCell
{
    func updateMaximumImageSize()
    {
        self.imageViewWidthConstraint.constant = self.maximumImageSize.width
        self.imageViewHeightConstraint.constant = self.maximumImageSize.height
        
        self.textLabelVerticalSpacingConstraint.constant = 8
        self.textLabelFocusedVerticalSpacingConstraint?.constant = self.maximumImageSize.height / 10.0
    }
}