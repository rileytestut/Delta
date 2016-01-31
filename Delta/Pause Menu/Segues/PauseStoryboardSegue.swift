//
//  PauseStoryboardSegue.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

class PauseStoryboardSegue: UIStoryboardSegue
{
    private let presentationController: PausePresentationController
    
    override init(identifier: String?, source: UIViewController, destination: UIViewController)
    {
        self.presentationController = PausePresentationController(presentedViewController: destination, presentingViewController: source)
        
        super.init(identifier: identifier, source: source, destination: destination)
    }
    
    override func perform()
    {
        self.destinationViewController.transitioningDelegate = self
        self.destinationViewController.modalPresentationStyle = .Custom
        self.destinationViewController.modalPresentationCapturesStatusBarAppearance = true
        
        super.perform()
    }
}

extension PauseStoryboardSegue: UIViewControllerTransitioningDelegate
{
    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return self
    }
    
    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return nil
    }
    
    func presentationControllerForPresentedViewController(presentedViewController: UIViewController, presentingViewController: UIViewController, sourceViewController source: UIViewController) -> UIPresentationController?
    {
        return self.presentationController
    }
}

extension PauseStoryboardSegue: UIViewControllerAnimatedTransitioning
{
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval
    {
        return 0.65
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning)
    {
        let destinationViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
        
        destinationViewController.view.frame = transitionContext.finalFrameForViewController(destinationViewController)
        destinationViewController.view.frame.origin.y = transitionContext.containerView()!.bounds.height
        transitionContext.containerView()!.addSubview(destinationViewController.view)
        
        UIView.animateWithDuration(self.transitionDuration(transitionContext), delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: {
            
            // Calling layoutIfNeeded before the animation block for some reason prevents the blur from fading in
            // Additionally, if it's animated, it looks weird
            // So we need to wrap it in a no-animation block, inside an animation block. Blech.
            UIView.performWithoutAnimation({
                destinationViewController.view.layoutIfNeeded()
            })
            
            destinationViewController.view.frame = self.presentationController.frameOfPresentedViewInContainerView()
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}
