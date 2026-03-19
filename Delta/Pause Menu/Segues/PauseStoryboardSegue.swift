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
    private let presentationAnimator: UIViewPropertyAnimator
    private let dismissalAnimator: UIViewPropertyAnimator
    private let presentationController: PausePresentationController
    
    private var isPresenting: Bool = false
    
    override init(identifier: String?, source: UIViewController, destination: UIViewController)
    {
        self.presentationAnimator = PauseStoryboardSegue.makeAnimator()
        self.dismissalAnimator = PauseStoryboardSegue.makeAnimator()
        
        self.presentationController = PausePresentationController(presentedViewController: destination, presenting: source, presentationAnimator: self.presentationAnimator)
        
        super.init(identifier: identifier, source: source, destination: destination)
    }
    
    override func perform()
    {
        self.destination.transitioningDelegate = self
        self.destination.modalPresentationStyle = .custom
        self.destination.modalPresentationCapturesStatusBarAppearance = true
        
        // Manually set tint color, since calling layoutIfNeeded will cause view to load, but with default system tint color.
        self.destination.view.tintColor = .white
        
        // We need to force layout of destinationViewController.view _before_ animateTransition(using:)
        // Otherwise, we'll get "Unable to simultaneously satisfy constraints" errors
        self.destination.view.frame = self.source.view.frame
        self.destination.view.layoutIfNeeded()
        
        if #available(iOS 26, *)
        {
            self.destination.view.clipsToBounds = true
            self.destination.view.layer.cornerRadius = 38.0
            self.destination.view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        }
        
        super.perform()
    }
    
    private class func makeAnimator() -> UIViewPropertyAnimator
    {
        if #available(iOS 26, *)
        {
            let timingParameters = UISpringTimingParameters()
            let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
            return animator
        }
        else
        {
            let timingParameters = UISpringTimingParameters(mass: 3.0, stiffness: 750, damping: 65, initialVelocity: CGVector(dx: 0, dy: 0))
            let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
            return animator
        }
    }
}

extension PauseStoryboardSegue: UIViewControllerTransitioningDelegate
{
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        self.isPresenting = true
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        self.isPresenting = false
        
        if #available(iOS 26, *)
        {
            return self
        }
        else
        {
            return nil
        }
    }
    
    func presentationController(forPresented presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, source: UIViewController) -> UIPresentationController?
    {
        return self.presentationController
    }
}

extension PauseStoryboardSegue: UIViewControllerAnimatedTransitioning
{
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return self.isPresenting ? self.presentationAnimator.duration : self.dismissalAnimator.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        let animator = self.isPresenting ? self.presentationAnimator : self.dismissalAnimator
        
        if self.isPresenting
        {
            let presentedView = transitionContext.view(forKey: .to)!
            let presentedViewController = transitionContext.viewController(forKey: .to)!
            
            // Layout pause icon + game name initially without animation.
            transitionContext.containerView.layoutIfNeeded()
            
            // Resize presentedView to expected size.
            presentedView.frame = transitionContext.finalFrame(for: presentedViewController)
            
            transitionContext.containerView.addSubview(presentedView)
            
            // Layout presented view initially without animation.
            presentedView.layoutIfNeeded()
            
            if #available(iOS 26, *)
            {
                guard let navigationController = presentedViewController.navigationController else {
                    assertionFailure("PauseStoryboardSegue requires a UINavigationController to animate on iOS 26.")
                    return
                }
                    
                if let pauseHostingController = navigationController.viewControllers.first as? PauseView.HostingController
                {
                    // Use Liquid Glass materialize animation
                    pauseHostingController.showItems(animated: true)
                }
                
                navigationController.navigationBar.alpha = 0.0
                
                animator.addAnimations {
                    // Perform at least one valid UIKit animation in animator block.
                    navigationController.navigationBar.alpha = 1.0
                }
            }
            else
            {
                // Position view off-screen
                presentedView.frame.origin.y = transitionContext.containerView.bounds.height

                animator.addAnimations {
                    // Layout again to animate presentedView to correct frame.
                    transitionContext.containerView.layoutIfNeeded()
                }
            }
        }
        else
        {
            guard #available(iOS 26, *) else {
                assertionFailure("PauseStoryboardSegue should only have a custom dismissal animation on iOS 26.")
                return
            }
            
            let presentedView = transitionContext.view(forKey: .from)!
            let presentedViewController = transitionContext.viewController(forKey: .from)!
            
            presentedView.frame = transitionContext.initialFrame(for: presentedViewController)
            
            guard let navigationController = presentedViewController.navigationController else {
                assertionFailure("PauseStoryboardSegue requires a UINavigationController to animate on iOS 26.")
                return
            }
            
            if let pauseHostingController = navigationController.viewControllers.first as? PauseView.HostingController
            {
                // Use Liquid Glass materialize animation
                pauseHostingController.hideItems(animated: true)
            }
            
            animator.addAnimations {
                // Perform at least one valid UIKit animation in animator block.
                navigationController.navigationBar.alpha = 0.0
            }
        }
        
        animator.addCompletion { position in
            transitionContext.completeTransition(position == .end)
        }
        
        animator.startAnimation()
    }
}
