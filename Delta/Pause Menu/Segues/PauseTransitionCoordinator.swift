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
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return 0.4
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        let destinationViewController = transitionContext.viewController(forKey: .to)!
        let sourceViewController = transitionContext.viewController(forKey: .from)!
        
        destinationViewController.view.frame = transitionContext.finalFrame(for: destinationViewController)
        destinationViewController.view.frame.origin.y = self.presenting ? transitionContext.containerView.bounds.height : -destinationViewController.view.bounds.height
        transitionContext.containerView.addSubview(destinationViewController.view)
        
        destinationViewController.view.layoutIfNeeded()
        
        if let navigationController = destinationViewController.navigationController
        {
            // Layout before animation to prevent strange bar button item layout during animation.
            navigationController.view.setNeedsLayout()
            navigationController.view.layoutIfNeeded()
        }
        
        if #available(iOS 26, *)
        {
            if let tableViewController = destinationViewController as? UITableViewController
            {
                let adjustedOffset = tableViewController.tableView.adjustedContentInset.top
                tableViewController.tableView.contentOffset = CGPoint(x: 0, y: -adjustedOffset)
            }
            else if let collectionViewController = destinationViewController as? UICollectionViewController
            {
                let adjustedOffset = collectionViewController.collectionView.adjustedContentInset.top
                collectionViewController.collectionView.contentOffset = CGPoint(x: 0, y: -adjustedOffset)
            }
        }
        
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay:0, options:RSTSystemTransitionAnimationCurve, animations: {
            
            sourceViewController.view.frame.origin.y = self.presenting ? -sourceViewController.view.bounds.height : transitionContext.containerView.bounds.height
            destinationViewController.view.frame.origin.y = 0
            
            self.presentationController.containerView?.setNeedsLayout()
            self.presentationController.containerView?.layoutIfNeeded()
            
            }) { finished in
                transitionContext.completeTransition(finished)
        }
    }
}

