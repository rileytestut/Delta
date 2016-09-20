//
//  GamesStoryboardSegue.swift
//  Delta
//
//  Created by Riley Testut on 8/7/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class GamesStoryboardSegue: UIStoryboardSegue
{
    fileprivate let animator: UIViewPropertyAnimator
    
    fileprivate var isPresenting: Bool = true
    
    override init(identifier: String?, source: UIViewController, destination: UIViewController)
    {
        let timingParameters = UISpringTimingParameters(mass: 3.0, stiffness: 750, damping: 65, initialVelocity: CGVector(dx: 0, dy: 0))
        self.animator = UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
        
        super.init(identifier: identifier, source: source, destination: destination)
    }
    
    override func perform()
    {
        self.destination.transitioningDelegate = self
        self.destination.modalPresentationStyle = .custom
        self.destination.modalPresentationCapturesStatusBarAppearance = true
        
        super.perform()
    }
}

extension GamesStoryboardSegue: UIViewControllerTransitioningDelegate
{
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        self.isPresenting = true
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        self.isPresenting = false
        return self
    }
    
    func presentationController(forPresented presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, source: UIViewController) -> UIPresentationController?
    {
        let presentationController = GamesPresentationController(presentedViewController: presentedViewController, presenting: presentingViewController)
        return presentationController
    }
}

extension GamesStoryboardSegue: UIViewControllerAnimatedTransitioning
{
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return self.animator.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        if self.isPresenting
        {
            self.animatePresentationTransition(using: transitionContext)
        }
        else
        {
            self.animateDismissalTransition(using: transitionContext)
        }
    }
    
    func animatePresentationTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        transitionContext.sourceViewController.beginAppearanceTransition(false, animated: true)
        
        transitionContext.destinationView.frame = transitionContext.destinationViewFinalFrame!
        transitionContext.destinationView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
        transitionContext.containerView.addSubview(transitionContext.destinationView)
        
        let snapshotView = transitionContext.sourceView.snapshotView(afterScreenUpdates: false)!
        snapshotView.frame = transitionContext.sourceViewInitialFrame!
        snapshotView.alpha = 1.0
        transitionContext.containerView.addSubview(snapshotView)
        
        // Ensures navigation controller toolbar (if visible) has been added to view heirachy, allowing us to add constraints
        transitionContext.containerView.layoutIfNeeded()
        
        // We add extra padding around the existing navigation bar and toolbar so they never appear to be detached from the edges of the screen during the overshooting of the spring animation
        var topPaddingToolbar: UIToolbar? = nil
        var bottomPaddingToolbar: UIToolbar? = nil
        
        if let navigationController = transitionContext.destinationViewController as? UINavigationController
        {
            let padding: CGFloat = 44
            
            if !navigationController.isNavigationBarHidden
            {
                let topToolbar = UIToolbar(frame: CGRect.zero)
                topToolbar.translatesAutoresizingMaskIntoConstraints = false
                topToolbar.barStyle = navigationController.toolbar.barStyle
                transitionContext.destinationView.insertSubview(topToolbar, belowSubview: navigationController.navigationBar)
                
                topToolbar.bottomAnchor.constraint(equalTo: navigationController.navigationBar.bottomAnchor).isActive = true
                topToolbar.centerXAnchor.constraint(equalTo: navigationController.navigationBar.centerXAnchor).isActive = true
                topToolbar.widthAnchor.constraint(equalTo: navigationController.navigationBar.widthAnchor, constant: padding * 2).isActive = true
                topToolbar.heightAnchor.constraint(equalTo: navigationController.navigationBar.heightAnchor, constant: padding).isActive = true
                
                topPaddingToolbar = topToolbar
            }
            
            if !navigationController.isToolbarHidden
            {
                let bottomToolbar = UIToolbar(frame: CGRect.zero)
                bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
                bottomToolbar.barStyle = navigationController.toolbar.barStyle
                transitionContext.destinationView.insertSubview(bottomToolbar, belowSubview: navigationController.navigationBar)
                
                bottomToolbar.topAnchor.constraint(equalTo: navigationController.toolbar.topAnchor).isActive = true
                bottomToolbar.centerXAnchor.constraint(equalTo: navigationController.toolbar.centerXAnchor).isActive = true
                bottomToolbar.widthAnchor.constraint(equalTo: navigationController.toolbar.widthAnchor, constant: padding * 2).isActive = true
                bottomToolbar.heightAnchor.constraint(equalTo: navigationController.toolbar.heightAnchor, constant: padding).isActive = true
                
                bottomPaddingToolbar = bottomToolbar
            }
        }

        self.animator.addAnimations {
            snapshotView.alpha = 0.0
            transitionContext.destinationView.transform = CGAffineTransform.identity
        }
        
        self.animator.addCompletion { (position) in
            transitionContext.completeTransition(position == .end)
            
            snapshotView.removeFromSuperview()
            
            topPaddingToolbar?.removeFromSuperview()
            bottomPaddingToolbar?.removeFromSuperview()
            
            transitionContext.sourceViewController.endAppearanceTransition()
        }
        
        self.animator.startAnimation()
    }
    
    func animateDismissalTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        transitionContext.destinationViewController.beginAppearanceTransition(true, animated: true)
        
        self.animator.addAnimations {
            transitionContext.sourceView.alpha = 0.0
            transitionContext.sourceView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
        }
        
        self.animator.addCompletion { (position) in
            transitionContext.completeTransition(position == .end)
            transitionContext.destinationViewController.endAppearanceTransition()
        }
        
        self.animator.startAnimation()
    }
}
