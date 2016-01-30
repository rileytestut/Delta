//
//  PauseTransitionCoordinator.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class PauseTransitionCoordinator: NSObject, UIViewControllerAnimatedTransitioning
{
    let presentationController: UIPresentationController
    var presenting = false
    
    init(presentationController: UIPresentationController)
    {
        self.presentationController = presentationController
        
        super.init()
    }
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval
    {
        return 0.4
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning)
    {
        let destinationViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        let sourceViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
        
        destinationViewController.view.frame = transitionContext.finalFrameForViewController(destinationViewController)
        destinationViewController.view.frame.origin.y = self.presenting ? transitionContext.containerView()!.bounds.height : -destinationViewController.view.bounds.height
        transitionContext.containerView()!.addSubview(destinationViewController.view)
        
        destinationViewController.view.layoutIfNeeded()
        
        UIView.animateWithDuration(self.transitionDuration(transitionContext), delay:0, options:RSTSystemTransitionAnimationCurve, animations: {
            
            sourceViewController.view.frame.origin.y = self.presenting ? -sourceViewController.view.bounds.height : transitionContext.containerView()!.bounds.height
            destinationViewController.view.frame.origin.y = 0
            
            self.presentationController.containerView?.setNeedsLayout()
            self.presentationController.containerView?.layoutIfNeeded()
            
            }) { finished in
                transitionContext.completeTransition(finished)
        }
    }
}

