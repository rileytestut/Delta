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
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.contentMode = .scaleAspectFit
        #if os(tvOS)
            self.imageView.adjustsImageWhenAncestorFocused = true
        #endif
        self.contentView.addSubview(self.imageView)
        
        self.textLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textLabel.font = UIFont.boldSystemFont(ofSize: 12)
        self.textLabel.textAlignment = .center
        self.textLabel.numberOfLines = 0
        self.contentView.addSubview(self.textLabel)
        
        // Auto Layout
        
        self.imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        self.imageView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor).isActive = true
        
        self.imageViewWidthConstraint = self.imageView.widthAnchor.constraint(equalToConstant: self.maximumImageSize.width)
        self.imageViewWidthConstraint.isActive = true
        
        self.imageViewHeightConstraint = self.imageView.heightAnchor.constraint(equalToConstant: self.maximumImageSize.height)
        self.imageViewHeightConstraint.isActive = true
        
        
        self.textLabel.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
        self.textLabel.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
        
        self.textLabelBottomAnchorConstraint = self.textLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        self.textLabelBottomAnchorConstraint.isActive = true
        
        self.textLabelVerticalSpacingConstraint = self.textLabel.topAnchor.constraint(equalTo: self.imageView.bottomAnchor)
        self.textLabelVerticalSpacingConstraint.isActive = true
        
        
        #if os(tvOS)
            self.textLabelVerticalSpacingConstraint.active = false
            
            self.textLabelFocusedVerticalSpacingConstraint = self.textLabel.topAnchor.constraintEqualToAnchor(self.imageView.focusedFrameGuide.bottomAnchor, constant: 0)
            self.textLabelFocusedVerticalSpacingConstraint?.active = true
        #else
            self.textLabelVerticalSpacingConstraint.isActive = true
        #endif
        
        
        self.updateMaximumImageSize()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator)
    {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            
            if context.nextFocusedView == self
            {
                self.textLabelBottomAnchorConstraint?.isActive = false
                self.textLabelVerticalSpacingConstraint.isActive = false
                
                self.textLabelFocusedVerticalSpacingConstraint?.isActive = true
                
                self.textLabel.textColor = UIColor.white
                
            }
            else
            {
                self.textLabelFocusedVerticalSpacingConstraint?.isActive = false
                
                self.textLabelBottomAnchorConstraint?.isActive = true
                self.textLabelVerticalSpacingConstraint.isActive = true
                
                self.textLabel.textColor = UIColor.black
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
