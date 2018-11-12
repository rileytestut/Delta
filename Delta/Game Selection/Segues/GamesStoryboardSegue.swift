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
    private let animator: UIViewPropertyAnimator
    
    private var isPresenting: Bool = true
    
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
        let presentationController = GamesPresentationController(presentedViewController: presentedViewController, presenting: presentingViewController, animator: self.animator)
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
        
        // We add extra padding around the existing navigation bar and toolbar so they never appear to be detached from the edges of the screen during the overshooting of the spring animation
        var topPaddingToolbar: UIToolbar? = nil
        var bottomPaddingToolbar: UIToolbar? = nil
        
        // Must be wrapped in no-animation block to prevent iOS 11 search bar from not appearing.
        UIView.performWithoutAnimation {
            // Ensures navigation controller toolbar (if visible) has been added to view heirachy, allowing us to add constraints
            transitionContext.containerView.layoutIfNeeded()
            
            if let navigationController = transitionContext.destinationViewController as? UINavigationController
            {
                let padding: CGFloat = 44
                
                if !navigationController.isNavigationBarHidden
                {
                    let topToolbar = UIToolbar(frame: CGRect.zero)
                    topToolbar.translatesAutoresizingMaskIntoConstraints = false
                    topToolbar.barStyle = navigationController.toolbar.barStyle
                    transitionContext.destinationView.insertSubview(topToolbar, at: 1)
                    
                    topToolbar.topAnchor.constraint(equalTo: navigationController.navigationBar.topAnchor, constant: -padding).isActive = true
                    topToolbar.leftAnchor.constraint(equalTo: navigationController.navigationBar.leftAnchor, constant: -padding).isActive = true
                    topToolbar.rightAnchor.constraint(equalTo: navigationController.navigationBar.rightAnchor, constant: padding).isActive = true
                    
                    // There is no easy way to determine the extra height necessary at this point of the transition, so hard code for now.
                    let additionalSearchBarHeight = 44 as CGFloat
                    topToolbar.heightAnchor.constraint(equalToConstant: navigationController.topViewController!.view.safeAreaInsets.top + additionalSearchBarHeight).isActive = true
                    
                    topPaddingToolbar = topToolbar
                }
                
                if !navigationController.isToolbarHidden
                {
                    let bottomToolbar = UIToolbar(frame: CGRect.zero)
                    bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
                    bottomToolbar.barStyle = navigationController.toolbar.barStyle
                    transitionContext.destinationView.insertSubview(bottomToolbar, belowSubview: navigationController.navigationBar)
                    
                    bottomToolbar.topAnchor.constraint(equalTo: navigationController.toolbar.topAnchor).isActive = true
                    bottomToolbar.bottomAnchor.constraint(equalTo: navigationController.toolbar.bottomAnchor, constant: padding).isActive = true
                    bottomToolbar.leftAnchor.constraint(equalTo: navigationController.toolbar.leftAnchor, constant: -padding).isActive = true
                    bottomToolbar.rightAnchor.constraint(equalTo: navigationController.toolbar.rightAnchor, constant: padding).isActive = true
                    
                    bottomPaddingToolbar = bottomToolbar
                }
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

