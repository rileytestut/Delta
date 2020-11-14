//
//  AppIconCell.swift
//  Delta
//
//  Created by Kyle Grieder on 10/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class AppIconCell: UITableViewCell {
    @IBOutlet var iconImage: UIImageView!
    @IBOutlet var iconLabel: UILabel!
    @IBOutlet var checkmark: UIImageView!
    
    public static var reuseIdentifier = "appIconCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.iconImage.layer.cornerRadius = 5.8
        self.iconImage.layer.borderWidth = 0.3
        self.iconImage.layer.borderColor = UIColor.lightGray.cgColor
        self.checkmark.isHidden = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
