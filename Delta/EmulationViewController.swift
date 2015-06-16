//
//  EmulationViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore
import SNESDeltaCore

class EmulationViewController: UIViewController
{
    let game: Game
    let emulatorCore: EmulatorCore
    @IBOutlet private(set) var controllerView: ControllerView!
    
    @IBOutlet private var controllerViewHeightConstraint: NSLayoutConstraint!
    
    required init(game: Game)
    {
        self.game = game
        self.emulatorCore = SNESEmulatorCore(game: game)
        
        super.init(nibName: "EmulationViewController", bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("initWithCoder: not implemented.")
    }
    
    //MARK: UIViewController
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let skinURL = self.game.URL.URLByDeletingLastPathComponent?.URLByAppendingPathComponent("Standard.deltaskin")
        let controllerSkin = ControllerSkin(URL: skinURL!)
        
        self.controllerView.controllerSkin = controllerSkin
        
        println(self.controllerView.intrinsicContentSize())
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.emulatorCore.startEmulation()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let scale = self.view.bounds.width / self.controllerView.intrinsicContentSize().width
        self.controllerViewHeightConstraint.constant = self.controllerView.intrinsicContentSize().height * scale
    }
    
    override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)
        
        self.controllerView.beginAnimatingUpdateControllerSkin()
        
        coordinator.animateAlongsideTransition(nil) { (context) in
            self.controllerView.finishAnimatingUpdateControllerSkin()
        }
    }
    
    override func prefersStatusBarHidden() -> Bool
    {
        return true
    }
}
