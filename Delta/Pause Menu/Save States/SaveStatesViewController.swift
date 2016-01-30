//
//  SaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/23/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class SaveStatesViewController: UICollectionViewController
{
    private var backgroundView: RSTBackgroundView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.whiteColor()
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
        self.backgroundView.detailTextLabel.textColor = UIColor.whiteColor()
        self.view.insertSubview(self.backgroundView, atIndex: 0)
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}