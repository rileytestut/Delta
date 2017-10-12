//
//  InputCalloutView.swift
//  Delta
//
//  Created by Riley Testut on 7/9/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import SMCalloutView

import DeltaCore

extension InputCalloutView
{
    enum State
    {
        case normal
        case listening
    }
}

class InputCalloutView: SMCalloutView
{
    var input: Input? {
        didSet {
            self.updateState()
        }
    }
    
    var state: State = .normal {
        didSet {
            self.updateState()
        }
    }
    
    private let textLabel: UILabel
    
    init()
    {
        self.textLabel = UILabel()
        self.textLabel.font = UIFont.boldSystemFont(ofSize: 18.0)
        self.textLabel.textAlignment = .center
        
        super.init(frame: CGRect.zero)
        
        self.titleView = self.textLabel
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange()
    {
        super.tintColorDidChange()
        
        self.updateTintColor()
    }
}

private extension InputCalloutView
{
    func updateState()
    {
        switch self.state
        {
        case .normal: self.textLabel.text = self.input?.localizedName
        case .listening: self.textLabel.text = NSLocalizedString("Press Button", comment: "")
        }
        
        self.updateTintColor()
        
        self.textLabel.sizeToFit()
    }
    
    func updateTintColor()
    {
        switch self.state
        {
        case .normal: self.textLabel.textColor = self.tintColor
        case .listening: self.textLabel.textColor = .red
        }
    }
}
