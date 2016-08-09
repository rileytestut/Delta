//
//  GamesPresentationController.swift
//  Delta
//
//  Created by Riley Testut on 8/7/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class GamesPresentationController: UIPresentationController
{
    private let blurView: UIVisualEffectView
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?)
    {
        self.blurView = UIVisualEffectView(effect: nil)
        self.blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    override func presentationTransitionWillBegin()
    {
        guard let containerView = self.containerView else { return }
        
        self.blurView.frame = CGRect(x: 0, y: 0, width: containerView.bounds.width, height: containerView.bounds.height)
        containerView.addSubview(self.blurView)

        self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (context) in
            self.blurView.effect = UIBlurEffect(style: .dark)
        })
    }
    
    override func dismissalTransitionWillBegin()
    {
        self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (context) in
            self.blurView.effect = nil
        })
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool)
    {
        self.blurView.removeFromSuperview()
    }
}
