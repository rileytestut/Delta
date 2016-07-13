//
//  PausePresentationController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

protocol PauseInfoProvidable
{
    var pauseText: String? { get }
}

class PausePresentationController: UIPresentationController
{
    private let blurringView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    
    private var contentView: UIView!
    @IBOutlet private weak var pauseLabel: UILabel!
    @IBOutlet private weak var pauseIconImageView: UIImageView!
    @IBOutlet private weak var stackView: UIStackView!
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?)
    {
        self.blurringView = UIVisualEffectView(effect: nil)
        self.vibrancyView = UIVisualEffectView(effect: nil)
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        
        self.contentView = Bundle.main.loadNibNamed("PausePresentationControllerContentView", owner: self, options: nil).first as! UIView
    }
    
    override func frameOfPresentedViewInContainerView() -> CGRect
    {
        guard let containerView = self.containerView else { return super.frameOfPresentedViewInContainerView() }
        
        let frame: CGRect
        let contentHeight = self.presentedViewController.preferredContentSize.height
        
        if contentHeight == 0
        {
            let statusBarHeight = UIApplication.shared().statusBarFrame.height
            frame = CGRect(x: 0, y: statusBarHeight, width: containerView.bounds.width, height: containerView.bounds.height - statusBarHeight)
        }
        else
        {
            frame = CGRect(x: 0, y: containerView.bounds.height - contentHeight, width: containerView.bounds.width, height: containerView.bounds.height)
        }
        
        return frame
    }
    
    override func presentationTransitionWillBegin()
    {
        if let provider = self.presentedViewController as? PauseInfoProvidable
        {
            self.pauseLabel.text = provider.pauseText
        }
        else if let navigationController = self.presentedViewController as? UINavigationController, provider = navigationController.topViewController as? PauseInfoProvidable
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
        
        self.presentingViewController.transitionCoordinator()?.animate(alongsideTransition: { context in
            
            let blurEffect = UIBlurEffect(style: .dark)
            
            self.blurringView.effect = blurEffect
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: blurEffect)
            
            self.contentView.alpha = 1.0
            
        }, completion: nil)
    }
    
    override func dismissalTransitionWillBegin()
    {
        self.presentingViewController.transitionCoordinator()?.animate(alongsideTransition: { context in
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
        
        if self.presentedView()!.frame.minY == 0
        {
            // Temporarily offset top of presentedView by a small amount to prevent navigation bar from growing when rotating from landscape to portrait
            self.presentedView()?.frame.origin.y = 0.5
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
        let statusBarHeight = UIApplication.shared().statusBarFrame.height
        self.contentView.frame = CGRect(x: 0, y: statusBarHeight, width: self.containerView!.bounds.width, height: self.containerView!.bounds.height - statusBarHeight)
        
        // Layout content view
        self.contentView.setNeedsLayout()
        self.contentView.layoutIfNeeded()
        
        // Add back to the view hierarchy
        self.vibrancyView.contentView.addSubview(self.contentView)
        
        
        /* Resume Normal Calculations */
        
        
        // Ensure width is correct
        self.presentedView()?.bounds.size.width = self.containerView!.bounds.width
        self.presentedView()?.setNeedsLayout()
        self.presentedView()?.layoutIfNeeded()
        
        self.presentedView()?.frame = self.frameOfPresentedViewInContainerView()
        
        // Unhide pauseIconImageView so its height is involved with layout calculations
        self.pauseIconImageView.isHidden = false
        
        self.contentView.frame = CGRect(x: 0, y: statusBarHeight, width: self.containerView!.bounds.width, height: self.frameOfPresentedViewInContainerView().minY - statusBarHeight)
        
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
