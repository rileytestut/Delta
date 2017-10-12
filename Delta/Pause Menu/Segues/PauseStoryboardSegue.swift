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
    private let animator: UIViewPropertyAnimator
    private let presentationController: PausePresentationController
    
    override init(identifier: String?, source: UIViewController, destination: UIViewController)
    {
        let timingParameters = UISpringTimingParameters(mass: 3.0, stiffness: 750, damping: 65, initialVelocity: CGVector(dx: 0, dy: 0))
        self.animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
        
        self.presentationController = PausePresentationController(presentedViewController: destination, presenting: source, presentationAnimator: self.animator)
        
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
        
        super.perform()
    }
}

extension PauseStoryboardSegue: UIViewControllerTransitioningDelegate
{
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return nil
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
        return self.animator.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        let presentedView = transitionContext.view(forKey: .to)!
        let presentedViewController = transitionContext.viewController(forKey: .to)!
        
        presentedView.frame = transitionContext.finalFrame(for: presentedViewController)
        presentedView.frame.origin.y = transitionContext.containerView.bounds.height
        transitionContext.containerView.addSubview(presentedView)
        
        self.animator.addAnimations { [unowned self] in
            presentedView.frame = self.presentationController.frameOfPresentedViewInContainerView
        }
        
        self.animator.addCompletion { position in
            transitionContext.completeTransition(position == .end)
        }
        
        self.animator.startAnimation()
    }
}
