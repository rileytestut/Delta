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
        
        var alertActionStyle: UIAlertActionStyle
        {
            switch self
            {
            case .default, .selected: return .default
            case .cancel: return .cancel
            case .destructive: return .destructive
            }
        }
        
        var previewActionStyle: UIPreviewActionStyle?
        {
            switch self
            {
            case .default: return .default
            case .destructive: return .destructive
            case .selected: return .selected
            case .cancel: return nil
            }
        }
    }
}

struct Action
{
    let title: String
    let style: Style
    let action: ((Action) -> Void)?
}

extension UIAlertAction
{
    convenience init(_ action: Action)
    {
        self.init(title: action.title, style: action.style.alertActionStyle) { (alertAction) in
            action.action?(action)
        }
    }
}

extension UIPreviewAction
{
    convenience init?(_ action: Action)
    {
        guard let previewActionStyle = action.style.previewActionStyle else { return nil }
        
        self.init(title: action.title, style: previewActionStyle) { (previewAction, viewController) in
            action.action?(action)
        }
    }
}

extension UIAlertController
{
    convenience init(actions: [Action])
    {
        self.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for action in actions.alertActions
        {
            self.addAction(action)
        }
    }
}

extension RangeReplaceableCollection where Iterator.Element == Action
{
    var alertActions: [UIAlertAction] {
        let actions = self.map { UIAlertAction($0) }
        return actions
    }
    
    var previewActions: [UIPreviewAction] {
        let actions = self.flatMap { UIPreviewAction($0) }
        return actions
    }
}
