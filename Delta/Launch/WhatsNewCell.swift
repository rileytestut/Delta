//
//  WhatsNewCollectionViewCell.swift
//  Delta
//
//  Created by Riley Testut on 2/18/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import UIKit

class WhatsNewCollectionViewCell: UICollectionViewCell
{
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var captionLabel: UILabel!
    
    @IBOutlet var patronsLabel: UILabel!
    
    @IBOutlet var imageView: UIImageView!
    
    @IBOutlet private var stackView: UIStackView!
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = 16
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        let fontDescriptor = self.nameLabel.font.fontDescriptor.withSymbolicTraits(.traitBold)!
        self.nameLabel.font = UIFont(descriptor: fontDescriptor, size: self.nameLabel.font.pointSize)
    }
}

extension WhatsNewCollectionViewCell
{
    func configure(with feature: WhatsNewViewController.NewFeature)
    {
        self.nameLabel.text = feature.name
        self.captionLabel.text = feature.caption
        self.imageView.image = UIImage(systemName: feature.icon)
        
        if feature.isPatronExclusive
        {
            self.patronsLabel.isHidden = false
            self.stackView.backgroundColor = .clear
            
            self.stackView.directionalLayoutMargins.top = 15
            self.stackView.directionalLayoutMargins.bottom = 15
            
            self.contentView.overrideUserInterfaceStyle = .light
        }
        else
        {
            self.patronsLabel.isHidden = true
            self.stackView.backgroundColor = .systemBackground
            
            self.stackView.directionalLayoutMargins.top = 8
            self.stackView.directionalLayoutMargins.bottom = 8
            
            self.contentView.overrideUserInterfaceStyle = .unspecified
        }
    }
}
