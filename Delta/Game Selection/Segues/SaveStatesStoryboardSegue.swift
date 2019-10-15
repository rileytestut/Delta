//
//  SaveStatesStoryboardSegue.swift
//  Delta
//
//  Created by Riley Testut on 9/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

class SaveStatesStoryboardSegue: UIStoryboardSegue
{
    private var destinationNavigationController: UINavigationController?
    
    override func perform()
    {
        super.perform()
        
        self.destinationNavigationController = self.destination as? UINavigationController
        
        guard let saveStatesViewController = self.destinationNavigationController?.topViewController as? SaveStatesViewController else { return }
        
        // Ensures saveStatesViewController doesn't later remove our Done button 
        saveStatesViewController.loadViewIfNeeded()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(SaveStatesStoryboardSegue.handleDoneButton))
        saveStatesViewController.navigationItem.leftBarButtonItem = doneButton
        
        guard saveStatesViewController.theme == .translucent else { return }
        
        let sourceView = self.source.navigationController!.view!
        
        let maskView = UIView(frame: CGRect(x: 0, y: 0, width: sourceView.bounds.width, height: sourceView.bounds.height))
        maskView.backgroundColor = UIColor.white
        sourceView.mask = maskView
        
        self.destination.transitionCoordinator?.animate(alongsideTransition: { (context) in
            maskView.frame.size.height = 0
        }, completion: { (context) in
            sourceView.mask = nil
        })
    }
    
    @objc private func handleDoneButton()
    {
        self.destinationNavigationController?.performSegue(withIdentifier: "unwindFromSaveStates", sender: nil)
    }
}

class SaveStatesStoryboardUnwindSegue: UIStoryboardSegue
{
    override func perform()
    {
        super.perform()
        
        guard let saveStatesViewController = (self.source as? UINavigationController)?.topViewController as? SaveStatesViewController, saveStatesViewController.theme == .translucent else { return }
        
        let destinationView = self.destination.navigationController!.view!
        
        let maskView = UIView(frame: CGRect(x: 0, y: 0, width: destinationView.bounds.width, height: 0))
        maskView.backgroundColor = UIColor.white
        destinationView.mask = maskView
        
        // Need to add a dummy view to view hierarchy + animate it to ensure UIViewPropertyAnimator actually runs the animations 🙄
        let dummyView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        dummyView.backgroundColor = UIColor.clear
        self.source.view?.window?.insertSubview(dummyView, at: 0)
        
        // Apparently UIViewControllerTransitionCoordinator doesn't run its additional animations with same timing curve as the transition animation, so we use our own spring animation
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: UISpringTimingParameters())
        animator.addAnimations {
            maskView.frame.size.height = destinationView.bounds.height
            dummyView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }
        animator.addCompletion { (position) in
            destinationView.mask = nil
            dummyView.removeFromSuperview()
        }
        
        animator.startAnimation()
    }
}
