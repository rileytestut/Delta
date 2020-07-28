//
//  SidebarView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import UIKit

import Roxas

@dynamicMemberLookup
class Box<Value>
{
    let value: Value
    
    init(_ value: Value)
    {
        self.value = value
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T
    {
        return value[keyPath: keyPath]
    }
}

extension SidebarView
{
    class ViewController: UICollectionViewController
    {
        @Binding var system: System?
        
        private lazy var dataSource = self.makeDataSource()
        
        init(system: Binding<System?>)
        {
            self._system = system
            
            let configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
            let layout = UICollectionViewCompositionalLayout.list(using: configuration)
            super.init(collectionViewLayout: layout)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad()
        {
            super.viewDidLoad()
            
            self.view.backgroundColor = .clear
            
            self.collectionView.dataSource = self.dataSource
            self.collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        }
        
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            
            print("Parent:", parent)
            
            self.navigationController?.view.backgroundColor = .purple
            self.splitViewController?.primaryBackgroundStyle = .sidebar
            self.splitViewController?.view.backgroundColor = .green
        }
    }
}

private extension SidebarView.ViewController
{
    func makeDataSource() -> RSTArrayCollectionViewDataSource<Box<System>>
    {
        let dataSource = RSTArrayCollectionViewDataSource(items: System.allCases.map(Box.init))
        dataSource.cellConfigurationHandler = { (cell, system, indexPath) in
            let cell = cell as! UICollectionViewListCell
            
            var content = cell.defaultContentConfiguration()
            content.image = UIImage(systemName: "gamecontroller")
            content.text = system.localizedName
            
            cell.contentConfiguration = content
        }
        
        return dataSource
    }
}

struct SidebarView: UIViewControllerRepresentable
{
    @Binding var system: System?
    
    func makeUIViewController(context: Context) -> ViewController
    {
        let viewController = ViewController(system: $system)
        return viewController
    }
    
    func updateUIViewController(_ viewController: ViewController, context: Context)
    {
        viewController.collectionView.reloadData()
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(system: .constant(.nes))
    }
}
