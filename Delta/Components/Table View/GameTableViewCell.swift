//
//  GameTableViewCell.swift
//  Delta
//
//  Created by Riley Testut on 3/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

class GameTableViewCell: UITableViewCell
{
    @IBOutlet private(set) var nameLabel: UILabel!
    @IBOutlet private(set) var artworkImageView: UIImageView!
    
    @IBOutlet private(set) var artworkImageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private(set) var artworkImageViewTrailingConstraint: NSLayoutConstraint!
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
