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
    @IBOutlet private(set) var imageView: UIImageView!
    @IBOutlet private(set) var textLabel: UILabel!
    
    var maximumImageSize: CGSize = CGSize(width: 100, height: 100) {
        didSet {
            self.updateMaximumImageSize()
        }
    }
    
    @IBOutlet private var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet private var imageViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet private var textLabelBottomAnchorConstraint: NSLayoutConstraint!
    
    @IBOutlet private var textLabelVerticalSpacingConstraint: NSLayoutConstraint!
    private var textLabelFocusedVerticalSpacingConstraint: NSLayoutConstraint?
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        // Fix super annoying Unsatisfiable Constraints message in debugger by setting autoresizingMask
        self.contentView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
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
        
        #if os(tvOS)
            self.textLabelVerticalSpacingConstraint.active = false
            
            self.textLabelFocusedVerticalSpacingConstraint = self.textLabel.topAnchor.constraintEqualToAnchor(self.imageView.focusedFrameGuide.bottomAnchor, constant: verticalSpacingConstant)
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
        
        self.textLabelVerticalSpacingConstraint.constant = self.maximumImageSize.height / 10.0
        self.textLabelFocusedVerticalSpacingConstraint?.constant = self.maximumImageSize.height / 10.0
    }
}