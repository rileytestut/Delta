//
//  UIApplication+Extensions.swift
//  Delta
//
//  Created by Ian Clawson on 12/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func topViewController(_ viewController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = viewController as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = viewController?.presentedViewController {
            return topViewController(presented)
        }
        
        return viewController
    }
}
