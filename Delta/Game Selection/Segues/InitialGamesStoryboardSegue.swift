//
//  InitialGamesStoryboardSegue.swift
//  Delta
//
//  Created by Riley Testut on 8/7/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class InitialGamesStoryboardSegue: UIStoryboardSegue
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

extension InitialGamesStoryboardSegue: UIViewControllerTransitioningDelegate
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
}

extension InitialGamesStoryboardSegue: UIViewControllerAnimatedTransitioning
{
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return self.isPresenting ? 0.0 : self.animator.duration
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
        transitionContext.sourceViewController.beginAppearanceTransition(false, animated: false)
        
        transitionContext.destinationView.alpha = 0.0
        transitionContext.destinationView.frame = transitionContext.destinationViewFinalFrame!
        transitionContext.containerView.addSubview(transitionContext.destinationView)
        
        UIView.animate(withDuration: 0.3, animations: {
            transitionContext.destinationView.alpha = 1.0
        }, completion: { finished in
            transitionContext.completeTransition(true)
            transitionContext.sourceViewController.endAppearanceTransition()
        })
    }
    
    func animateDismissalTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        transitionContext.destinationViewController.beginAppearanceTransition(true, animated: true)
        
        transitionContext.destinationView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        transitionContext.destinationView.alpha = 0.0
        
        self.animator.addAnimations {
            transitionContext.sourceView.alpha = 0.0
            transitionContext.sourceView.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            
            transitionContext.destinationView.alpha = 1.0
            transitionContext.destinationView.transform = CGAffineTransform.identity
        }
        
        self.animator.addCompletion { (position) in
            transitionContext.completeTransition(position == .end)
            transitionContext.destinationViewController.endAppearanceTransition()
        }
        
        self.animator.startAnimation()
    }
}
