//
//  PopoverMenuViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class ListMenuViewController: UITableViewController
{
    var items: [MenuItem] {
        get { return self.dataSource.items }
        set { self.dataSource.items = newValue; }
    }
    
    fileprivate let dataSource = RSTArrayTableViewDataSource<MenuItem>(items: [])
    
    override var preferredContentSize: CGSize {
        get {
            let navigationBarHeight = self.navigationController?.navigationBar.bounds.height ?? 0.0
            return CGSize(width: 0, height: (self.tableView.rowHeight * CGFloat(self.items.count)) + navigationBarHeight)
        }
        set {}
    }
    
    init()
    {
        super.init(style: .plain)
        
        self.dataSource.cellConfigurationHandler = { (cell, item, indexPath) in
            cell.textLabel?.text = item.text
            cell.accessoryType = item.isSelected ? .checkmark : .none
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
        self.tableView.rowHeight = 44
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
    }
}

extension ListMenuViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        self.items.forEach { $0.isSelected = false }
        
        let item = self.dataSource.item(at: indexPath)
        item.isSelected = true
        item.action(item)
        
        self.tableView.reloadData()
        
        self.dismiss(animated: true, completion: nil)
    }
}
