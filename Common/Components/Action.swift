//
//  Action.swift
//  Delta
//
//  Created by Riley Testut on 5/18/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

extension Action
{
    enum Style
    {
        case `default`
        case cancel
        case destructive
        case selected
    }
}

extension Action.Style
{
    var alertActionStyle: UIAlertActionStyle
    {
        switch self
        {
        case .default, .selected: return .default
        case .cancel: return .cancel
        case .destructive: return .destructive
        }
    }
    
    var previewActionStyle: UIPreviewActionStyle
    {
        switch self
        {
        case .default, .cancel: return .default
        case .destructive: return .destructive
        case .selected: return .selected
        }
    }
}

struct Action
{
    let title: String
    let style: Style
    let action: ((Action) -> Void)?
    
    var alertAction: UIAlertAction
    {
        let alertAction = UIAlertAction(title: self.title, style: self.style.alertActionStyle) { (action) in
            self.action?(self)
        }
        return alertAction
    }
    
    var previewAction: UIPreviewAction
    {
        let previewAction = UIPreviewAction(title: self.title, style: self.style.previewActionStyle) { (action, viewController) in
            self.action?(self)
        }
        return previewAction
    }
}

// There is no public designated initializer for UIAlertAction or UIPreviewAction, so we cannot add our own convenience init
// If only there were factory initializers... https://github.com/apple/swift-evolution/pull/247
/*
extension UIAlertAction
{
    convenience init(action: Action)
    {
    }
}

extension UIPreviewAction
{
    convenience init(action: Action)
    {
    }
}
*/
