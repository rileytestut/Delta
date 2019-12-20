//
//  DeltaTVTabBarController.swift
//  DeltaTV
//
//  Created by Ian Clawson on 12/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class DeltaTVTabBarController: UITabBarController {
    
    lazy var menuTapGestureRecognizer: UITapGestureRecognizer = {
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(DeltaTVTabBarController.handleMenuGesture(_:)))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        return menuGesture
    }()

    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator)
    {
        // if the system focus is on the tab bar, we want to exit to the home screen rather
        // than moving up the view hierarchy into the game view conroller. There's no nice
        // native way to override the menu behavior, so we override the menu button with a
        // tap gesture instead, and add/remove the recognizer as neccessary
        if let target = context.nextFocusedView {
            if (target.isDescendant(of: self.tabBar)) {
                self.view.addGestureRecognizer(menuTapGestureRecognizer)
            } else {
                self.view.removeGestureRecognizer(menuTapGestureRecognizer)
            }
        }
    }
    
    @objc func handleMenuGesture(_ tap: UITapGestureRecognizer)
    {
        // exit to tvOS home screen
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

}
