//
//  LicensesViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/7/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class LicensesViewController: UIViewController
{
    private var _didAppear = false
    
    @IBOutlet private var textView: UITextView!
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        
        // Fix incorrect initial offset on iPhone SE.
        self.textView.contentOffset.y = 0
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        _didAppear = true
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        self.textView.textContainerInset.left = self.view.layoutMargins.left
        self.textView.textContainerInset.right = self.view.layoutMargins.right
        self.textView.textContainer.lineFragmentPadding = 0
        
        if !_didAppear
        {
            // Fix incorrect initial offset on iPhone SE.
            self.textView.contentOffset.y = 0
        }
    }
}
