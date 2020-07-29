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

class SidebarCell: UICollectionViewListCell
{
    override func updateConfiguration(using state: UICellConfigurationState)
    {
        var state = state
//        state.isSelected = false
        
        var configuration = UIBackgroundConfiguration.listSidebarCell().updated(for: state)
        
//        if let visualEffect = configuration.visualEffect
//        {
//            if state.isSelected
//            {
//                print("Selected traits:", state.traitCollection)
//            }
//            else
//            {
//                print("Deselected traits:", state.traitCollection)
//            }
//        }
//
//
        if state.isSelected
        {
//            if let visualEffect = configuration.visualEffect
//            {
//                print("Selected traits:", state.traitCollection)
//            }
//            else
//            {
//                print("Deselected traits:", state.traitCollection)
//            }
//
//            dump(state)
            
            configuration.customView = nil
        }
        else
        {
            configuration.backgroundColor = .clear
        }
        
//        configuration.backgroundColorTransformer = .grayscale
        
//        if state.isSelected
//        {
//            configuration.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
//        }
//        else
//        {
//            configuration.backgroundColor = .clear
//        }
//
//        print("Highlighted: \(state.isHighlighted). Selected: \(state.isSelected)")
//
        self.backgroundConfiguration = configuration
    }
}

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
            self.collectionView.register(SidebarCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
            
            self.navigationController?.navigationBar.isHidden = true
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
            cell.automaticallyUpdatesBackgroundConfiguration = false
            cell.automaticallyUpdatesContentConfiguration = false
            
            var content = cell.defaultContentConfiguration()
            content.image = UIImage(systemName: "gamecontroller")
            content.text = system.localizedName
            cell.contentConfiguration = content
        }
        
        return dataSource
    }
}

extension SidebarView.ViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let system = self.dataSource.item(at: indexPath)
        self.system = system.value
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
