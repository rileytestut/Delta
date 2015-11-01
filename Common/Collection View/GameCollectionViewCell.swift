//
//  GameCollectionViewCell.swift
//  Delta
//
//  Created by Riley Testut on 10/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class GameCollectionViewCell: UICollectionViewCell
{
    let imageView = BoxArtImageView()
    let nameLabel = UILabel()
    
    private var maximumBoxArtSize: CGSize = CGSize(width: 100, height: 100) {
        didSet
        {
            self.imageViewWidthConstraint.constant = self.maximumBoxArtSize.width
            self.imageViewHeightConstraint.constant = self.maximumBoxArtSize.height
            
            self.nameLabelVerticalSpacingConstraint.constant = self.maximumBoxArtSize.height / 20.0
            self.nameLabelFocusedVerticalSpacingConstraint?.constant = self.maximumBoxArtSize.height / 20.0
            
        }
    }
    
    private var imageViewWidthConstraint: NSLayoutConstraint!
    private var imageViewHeightConstraint: NSLayoutConstraint!
    
    private var nameLabelBottomAnchorConstraint: NSLayoutConstraint!
    
    private var nameLabelVerticalSpacingConstraint: NSLayoutConstraint!
    private var nameLabelFocusedVerticalSpacingConstraint: NSLayoutConstraint?
    
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
        // Fix super annoying Unsatisfiable Constraints message in debugger
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.imageView)
        
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.nameLabel.font = UIFont.boldSystemFontOfSize(12)
        self.nameLabel.textAlignment = .Center
        self.nameLabel.numberOfLines = 0
        self.contentView.addSubview(self.nameLabel)
        
        
        // Auto Layout
        
        self.imageView.leadingAnchor.constraintEqualToAnchor(self.contentView.leadingAnchor).active = true
        self.imageView.trailingAnchor.constraintEqualToAnchor(self.contentView.trailingAnchor).active = true
        self.imageView.topAnchor.constraintEqualToAnchor(self.contentView.topAnchor).active = true
        
        let verticalSpacingConstant = self.maximumBoxArtSize.height / 20.0
        
        self.nameLabelVerticalSpacingConstraint = self.nameLabel.topAnchor.constraintEqualToAnchor(self.imageView.bottomAnchor, constant: verticalSpacingConstant)
        
        #if os(tvOS)
            
            self.nameLabelVerticalSpacingConstraint.active = false
            
            self.nameLabelFocusedVerticalSpacingConstraint = self.nameLabel.topAnchor.constraintEqualToAnchor(self.imageView.focusedFrameGuide.bottomAnchor, constant: verticalSpacingConstant)
            self.nameLabelFocusedVerticalSpacingConstraint?.active = true
        #else
            self.nameLabelVerticalSpacingConstraint.active = true
        #endif
        
        self.nameLabel.leadingAnchor.constraintEqualToAnchor(self.contentView.leadingAnchor).active = true
        self.nameLabel.trailingAnchor.constraintEqualToAnchor(self.contentView.trailingAnchor).active = true
        
        self.nameLabelBottomAnchorConstraint =  self.nameLabel.bottomAnchor.constraintEqualToAnchor(self.contentView.bottomAnchor)
        self.nameLabelBottomAnchorConstraint.active = true
        
        self.imageViewWidthConstraint = self.imageView.widthAnchor.constraintEqualToConstant(self.maximumBoxArtSize.width)
        self.imageViewWidthConstraint.active = true
        
        self.imageViewHeightConstraint = self.imageView.heightAnchor.constraintEqualToConstant(self.maximumBoxArtSize.height)
        self.imageViewHeightConstraint.active = true
    }
    
    override func applyLayoutAttributes(layoutAttributes: UICollectionViewLayoutAttributes)
    {
        guard let attributes = layoutAttributes as? GameCollectionViewLayoutAttributes else { return }
        
        self.maximumBoxArtSize = attributes.maximumBoxArtSize
    }
    
    override func didUpdateFocusInContext(context: UIFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator)
    {
        super.didUpdateFocusInContext(context, withAnimationCoordinator: coordinator)
        
        coordinator.addCoordinatedAnimations({
            
            if context.nextFocusedView == self
            {
                self.nameLabelBottomAnchorConstraint?.active = false
                self.nameLabelVerticalSpacingConstraint.active = false
                
                self.nameLabelFocusedVerticalSpacingConstraint?.active = true
                
                self.nameLabel.textColor = UIColor.whiteColor()
                
            }
            else
            {
                self.nameLabelFocusedVerticalSpacingConstraint?.active = false
                
                self.nameLabelBottomAnchorConstraint?.active = true
                self.nameLabelVerticalSpacingConstraint.active = true
                
                self.nameLabel.textColor = UIColor.blackColor()
            }
            
            self.layoutIfNeeded()
            
        }, completion: nil)
    }
    
    
}
