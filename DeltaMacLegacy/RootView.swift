//
//  ContentViewController.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

extension RootView
{
    class ViewController: UIViewController
    {
        let primaryView: Primary
        let secondaryView: Secondary
        
        private var childSplitViewController: UISplitViewController!
        
        init(primaryView: Primary, secondaryView: Secondary)
        {
            self.primaryView = primaryView
            self.secondaryView = secondaryView
            
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad()
        {
            super.viewDidLoad()
            
            self.view.backgroundColor = .orange
            
            self.childSplitViewController = UISplitViewController(style: .doubleColumn)
//            self.childSplitViewController.primaryBackgroundStyle = .sidebar
            
            let primaryViewController = UIHostingController(rootView: self.primaryView)
//            let primaryViewController = UIViewController()
            primaryViewController.view.backgroundColor = .clear
            self.childSplitViewController.setViewController(primaryViewController, for: .primary)
            
            let secondaryViewController = UIHostingController(rootView: self.secondaryView)
//            let secondaryViewController = UIViewController()
            self.childSplitViewController.setViewController(secondaryViewController, for: .secondary)
            
            self.view.addSubview(self.childSplitViewController.view, pinningEdgesWith: .zero)
            self.addChild(self.childSplitViewController)
            self.childSplitViewController.didMove(toParent: self)
        }
    }
}

struct RootView<Primary: View, Secondary: View>: UIViewControllerRepresentable
{
    let primary: Primary
    let secondary: Secondary
    
    init(primary: Primary, secondary: Secondary)
    {
        self.primary = primary
        self.secondary = secondary
    }
    
    func makeUIViewController(context: Context) -> ViewController
    {
        let viewController = ViewController(primaryView: primary,
                                            secondaryView: secondary)
        return viewController
    }
    
    func updateUIViewController(_ viewController: ViewController, context: Context)
    {
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(primary: Text("Hi"), secondary: Text("Ho"))
    }
}
