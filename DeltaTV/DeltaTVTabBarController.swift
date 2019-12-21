//
//  DeltaTVTabBarController.swift
//  DeltaTV
//
//  Created by Ian Clawson on 12/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class DeltaTVTabBarController: UITabBarController {

    // the crux of the issue is thus;
    // if the system focus is on the tab bar, we want to exit to the home screen rather
    // than moving up the view hierarchy into the game view conroller. There's no nice
    // native way to override the menu behavior, so we override the menu button with a
    // tap gesture instead, and add/remove the recognizer as neccessary
    
    lazy var menuTapGestureRecognizer: UITapGestureRecognizer = {
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(DeltaTVTabBarController.handleMenuGesture(_:)))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        return menuGesture
    }()

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.delegate = self
    }
    
    func handleFocusCheckResult(isAtTop: Bool) {
        print("<><><> finishFocusCheck: \(isAtTop)")
        if isAtTop {
            self.view.addGestureRecognizer(menuTapGestureRecognizer)
        } else {
            self.view.removeGestureRecognizer(menuTapGestureRecognizer)
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator)
    {
        guard
            let target = context.nextFocusedView
            else {
                handleFocusCheckResult(isAtTop: false)
                return
        }
        
        // first check to see if the tab bar is in focus before anything else
        if target.isDescendant(of: self.tabBar) {
            checkIfMenuGestureShouldBeModified()
        } else {
            handleFocusCheckResult(isAtTop: false)
        }
    }
    
    func checkIfMenuGestureShouldBeModified() {
        
        guard
            let selected = self.selectedViewController,
            let topLevelVCs = self.viewControllers
            else {
                handleFocusCheckResult(isAtTop: false)
                return
        }
        
        var topLevelViewControllers = [UIViewController]()
        
        // some of the tab bar's view controllers are Navigation Controllers, if so get the first VC in the nav stack
        for viewController in topLevelVCs {
            if let nav = viewController as? UINavigationController, let firstVC = nav.viewControllers.first {
                topLevelViewControllers.append(firstVC)
            } else {
                topLevelViewControllers.append(viewController)
            }
        }

        
        print("<><><><>")
        print("<><><><>")
        print("<><><><> - didUpdateFocus")
        
        for vc in topLevelViewControllers {
            print("<> - toplevelvc:\(NSStringFromClass(vc.classForCoder))")
        }

        if let topSelected = topViewController(selected), topLevelViewControllers.contains(topSelected) {
            print("<><><><> - topSelected:\(NSStringFromClass(topSelected.classForCoder))")
            handleFocusCheckResult(isAtTop: true)
        } else {
            handleFocusCheckResult(isAtTop: false)
        }
    }
    
    @objc func handleMenuGesture(_ tap: UITapGestureRecognizer)
    {
        // exit to tvOS home screen
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

}

extension DeltaTVTabBarController: UITabBarControllerDelegate {
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // check on every time the tab bar focus changes
        checkIfMenuGestureShouldBeModified()
    }
}
