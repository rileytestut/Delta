//
//  RootViewController.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/28/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

import Roxas

class RootViewController: UIViewController
{
    lazy var sidebar: Sidebar = Sidebar(system: self.systemBinding)
    lazy var gameCollectionView = GameCollectionView(system: nil)

    private var system: System? {
        didSet {
            self.update()
        }
    }
    private lazy var systemBinding: Binding<System?> = {
        Binding(get: { self.system }, set: { self.system = $0 })
    }()
    
    private var childSplitViewController: UISplitViewController!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        self.childSplitViewController = UISplitViewController(style: .doubleColumn)
        self.childSplitViewController.preferredSplitBehavior = .tile
        self.childSplitViewController.primaryBackgroundStyle = .sidebar
        
        let primaryViewController = SidebarView.ViewController(system: systemBinding)
//        primaryViewController.view.backgroundColor = .clear
//        navigationController.navigationBar.isHidden = true
        
//        let primaryViewController = UITableViewController()
        self.childSplitViewController.setViewController(primaryViewController, for: .primary)
        
        let secondaryViewController = UIHostingController(rootView: self.gameCollectionView)
//            let secondaryViewController = UIViewController()
//        navigationController2.navigationBar.isHidden = true
        self.childSplitViewController.setViewController(secondaryViewController, for: .secondary)
        
        self.view.addSubview(self.childSplitViewController.view, pinningEdgesWith: .zero)
        self.addChild(self.childSplitViewController)
        self.childSplitViewController.didMove(toParent: self)
    }
}

private extension RootViewController
{
    func update()
    {
        if self.gameCollectionView.system != self.system
        {
            self.gameCollectionView = GameCollectionView(system: self.system)
            self.childSplitViewController.setViewController(UIHostingController(rootView: self.gameCollectionView), for: .secondary)
        }
    }
}
