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
    enum Style: Hashable
    {
        case `default`
        case cancel
        case destructive
        case selected
        
        var alertActionStyle: UIAlertAction.Style {
            switch self
            {
            case .default, .selected: return .default
            case .cancel: return .cancel
            case .destructive: return .destructive
            }
        }
    }
}

@available(iOS 13, *)
extension Action.Style
{
    var menuAttributes: UIMenuElement.Attributes {
        switch self
        {
        case .default, .cancel, .selected: return []
        case .destructive: return  .destructive
        }
    }
    
    var menuState: UIMenuElement.State {
        switch self
        {
        case .default, .cancel, .destructive: return .off
        case .selected: return .on
        }
    }
}

struct Action: Hashable
{
    var title: String
    var style: Style
    var image: UIImage? = nil
    var action: ((Action) -> Void)?
    
    init(title: String, style: Style = .default, image: UIImage? = nil, action: ((Action) -> Void)? = nil)
    {
        self.title = title
        self.style = style
        self.image = image
        self.action = action
    }
    
    static func ==(lhs: Action, rhs: Action) -> Bool
    {
        return lhs.title == rhs.title && lhs.style == rhs.style && lhs.image == rhs.image
    }
    
    func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.title)
        hasher.combine(self.style)
        hasher.combine(self.image)
    }
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

@available(iOS 13.0, *)
extension UIAction
{
    convenience init?(_ action: Action)
    {
        guard action.style != .cancel else { return nil }
        
        self.init(title: action.title, image: action.image, attributes: action.style.menuAttributes, state: action.style.menuState) { _ in
            action.action?(action)
        }
    }
}

extension RangeReplaceableCollection where Iterator.Element == Action
{
    var alertActions: [UIAlertAction] {
        let actions = self.map { UIAlertAction($0) }
        return actions
    }
    
    @available(iOS 13.0, *)
    var menuActions: [UIAction] {
        let actions = self.compactMap { UIAction($0) }
        return actions
    }
}
