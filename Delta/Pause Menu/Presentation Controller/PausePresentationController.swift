//
//  PausePresentationController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

protocol PauseInfoProviding
{
    var pauseText: String? { get }
}

class PausePresentationController: UIPresentationController
{
    let presentationAnimator: UIViewPropertyAnimator
    
    private let blurringView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    
    private var contentView: UIView!
    
    // Must not be weak, or else may result in crash when deallocating.
    @IBOutlet private var pauseLabel: UILabel!
    @IBOutlet private var pauseIconImageView: UIImageView!
    @IBOutlet private var stackView: UIStackView!
    
    override var frameOfPresentedViewInContainerView: CGRect
    {
        guard let containerView = self.containerView else { return super.frameOfPresentedViewInContainerView }
        
        var frame: CGRect
        let contentHeight = self.presentedViewController.preferredContentSize.height
        
        if contentHeight == 0
        {
            #if os(iOS)
            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            #else
            let statusBarHeight: CGFloat = 30 // TODO FIXME
            #endif
            frame = CGRect(x: 0, y: statusBarHeight, width: containerView.bounds.width, height: containerView.bounds.height - statusBarHeight)
        }
        else
        {
            frame = CGRect(x: 0, y: containerView.bounds.height - contentHeight, width: containerView.bounds.width, height: containerView.bounds.height)
            frame.origin.y -= containerView.safeAreaInsets.bottom
        }
        
        return frame
    }
    
    init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, presentationAnimator: UIViewPropertyAnimator)
    {
        self.presentationAnimator = presentationAnimator
        
        self.blurringView = UIVisualEffectView(effect: nil)
        self.vibrancyView = UIVisualEffectView(effect: nil)
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        
        self.contentView = Bundle.main.loadNibNamed("PausePresentationControllerContentView", owner: self, options: nil)?.first as? UIView
    }
    
    override func presentationTransitionWillBegin()
    {
        if let provider = self.presentedViewController as? PauseInfoProviding
        {
            self.pauseLabel.text = provider.pauseText
        }
        else if
            let navigationController = self.presentedViewController as? UINavigationController,
            let provider = navigationController.topViewController as? PauseInfoProviding
        {
            self.pauseLabel.text = provider.pauseText
        }
        else
        {
            self.pauseLabel.text = nil
        }
        
        self.blurringView.frame = self.containerView!.frame
        self.blurringView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.containerView?.addSubview(self.blurringView)
        
        self.vibrancyView.frame = self.containerView!.frame
        self.vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.containerView?.addSubview(self.vibrancyView)
        
        self.contentView.alpha = 0.0
        self.vibrancyView.contentView.addSubview(self.contentView)
        
        self.presentationAnimator.addAnimations {
            let blurEffect = UIBlurEffect(style: .dark)
            
            self.blurringView.effect = blurEffect
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: blurEffect)
            
            self.contentView.alpha = 1.0
        }
        
        // I have absolutely no clue why animating with transition coordinator results in no animation on iOS 11.
        // Spent far too long trying to fix it, so just use the presentation animator.
        // self.presentingViewController.transitionCoordinator?.animate(alongsideTransition: { context in }, completion: nil)
    }
    
    override func dismissalTransitionWillBegin()
    {
        self.presentingViewController.transitionCoordinator?.animate(alongsideTransition: { context in
            self.blurringView.effect = nil
            self.vibrancyView.effect = nil
            self.contentView.alpha = 0.0
        }, completion: nil)
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool)
    {
        self.blurringView.removeFromSuperview()
        self.vibrancyView.removeFromSuperview()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Super super hacky, but the system for some reason tries to layout the view in a (slightly) smaller space, which sometimes breaks constraints
        // To fix this, we ensure there is enough room for the constraints to be valid temporarily, and then the frame will be fixed in containerViewDidLayoutSubviews()
        let currentY = self.contentView.frame.minY
        self.contentView.frame = self.containerView!.bounds
        self.contentView.frame.origin.y = currentY
        
        if self.presentedView!.frame.minY == 0
        {
            // Temporarily offset top of presentedView by a small amount to prevent navigation bar from growing when rotating from landscape to portrait
            self.presentedView?.frame.origin.y = 0.5
        }
    }

    override func containerViewDidLayoutSubviews()
    {
        super.containerViewDidLayoutSubviews()
        
        // Magical calculations. If you edit ANY of them, you have to make sure everything still lays out correctly on *all* devices
        // So, I'd recommend that you not touch this :)
        
        
        /* Hacky Layout Bug Workaround */
        
        
        // For some reason, attempting to calculate the layout while contentView is in the view hierarchy doesn't properly follow constraint priorities exactly
        // Specifically, on 5s with long pause label text, it will sometimes resize the text before the image, or it will not resize the image enough for the size class
        self.contentView.removeFromSuperview()
        
        // Temporarily match the bounds of self.containerView (accounting for the status bar)
        #if os(iOS)
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        #else
        let statusBarHeight: CGFloat = 30 // TODO FIXME
        #endif
        self.contentView.frame = CGRect(x: 0, y: statusBarHeight, width: self.containerView!.bounds.width, height: self.containerView!.bounds.height - statusBarHeight)
        
        // Layout content view
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()
        
        // Add back to the view hierarchy
        self.vibrancyView.contentView.addSubview(self.contentView)
        
        
        /* Resume Normal Calculations */
        
        
        // Ensure width is correct
        self.presentedView?.bounds.size.width = self.containerView!.bounds.width
        self.presentedView?.setNeedsLayout()
        self.presentedView?.layoutIfNeeded()
        
        if self.presentingViewController.transitionCoordinator == nil
        {
            self.presentedView?.frame = self.frameOfPresentedViewInContainerView
        }
        
        // Unhide pauseIconImageView so its height is involved with layout calculations
        self.pauseIconImageView.isHidden = false
        
        self.contentView.frame = CGRect(x: 0, y: statusBarHeight, width: self.containerView!.bounds.width, height: self.frameOfPresentedViewInContainerView.minY - statusBarHeight)
        
        self.contentView.setNeedsLayout() // Ensures that layout will actually occur (sometimes the system thinks a layout is not needed, which messes up calculations)
        self.contentView.layoutIfNeeded()
        
        let currentScaleFactor = self.pauseLabel.currentScaleFactor
        if currentScaleFactor < self.pauseLabel.minimumScaleFactor || CGFloatEqualToFloat(currentScaleFactor, self.pauseLabel.minimumScaleFactor)
        {
            self.pauseIconImageView.isHidden = true
        }
        else
        {
            self.pauseIconImageView.isHidden = false
        }
        
        self.contentView.setNeedsLayout() // Ensures that layout will actually occur (sometimes the system thinks a layout is not needed, which messes up calculations)
        self.contentView.layoutIfNeeded()
    }
}
