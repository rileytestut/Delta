//
//  GameViewController+ExperimentalToasts.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/26/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Roxas

extension GameViewController
{
    func presentExperimentalToastView(_ text: String)
    {
        func presentToastView()
        {
            guard ExperimentalFeatures.shared.toastNotifications.isEnabled else { return }
            
            let duration = ExperimentalFeatures.shared.toastNotifications.duration
            
            let toastView = RSTToastView(text: text, detailText: nil)
            toastView.edgeOffset.vertical = 8
            toastView.textLabel.textAlignment = .center
            toastView.presentationEdge = .top
            toastView.show(in: self.view, duration: duration)
        }
        
        DispatchQueue.main.async {
            if let transitionCoordinator = self.transitionCoordinator
            {
                transitionCoordinator.animate(alongsideTransition: nil) { (context) in
                    presentToastView()
                }
            }
            else
            {
                presentToastView()
            }
        }
    }
}
