//
//  AppIconsViewController.swift
//  Delta
//
//  Created by Ian Clawson on 6/24/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit

enum AppIconData: Int, CaseIterable
{
    case purple
    case blue
    case green
    case orange
    case pink
    case pride
    
    func displayTitle() -> String
    {
        switch self
        {
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .pride: return "Pride"
        }
    }
    
    func key() -> String
    {
        switch self
        {
        case .purple: return "Delta-Icon"
        case .blue: return "Delta-Icon-Blue"
        case .green: return "Delta-Icon-Green"
        case .orange: return "Delta-Icon-Orange"
        case .pink: return "Delta-Icon-Pink"
        case .pride: return "Delta-Icon-Pride"
        }
    }
}

class AppIconsViewController: UITableViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.title = "Select App Icon"
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.tableFooterView = UIView()
    }
    
}

//MARK: - Delegate
extension AppIconsViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 80
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
        guard let icon = AppIconData(rawValue: indexPath.row) else { return }
        DispatchQueue.main.async
        {
            UIApplication.shared.setAlternateIconName(icon.key(), completionHandler: { (error) in
                if let error = error
                {
                    print("App icon failed to change due to \(error.localizedDescription)")
                }
                else
                {
                    print("App icon changed successfully")
                    Settings.lastAppIconKey = icon.key()
                    self.tableView.reloadData()
                }
            })
        }
    }
}

//MARK: - Data Source
extension AppIconsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return AppIconData.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let icon = AppIconData(rawValue: indexPath.row) else { return UITableViewCell() }
        
        var cell = tableView.dequeueReusableCell(withIdentifier: "SelectAppIconRow")
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "SelectAppIconRow")
        }
        cell?.textLabel?.text = icon.displayTitle()
        cell?.imageView?.image = UIImage(named: icon.key())
        cell?.accessoryType = icon.key() == Settings.lastAppIconKey ? .checkmark : .none
        return cell!
    }
    
}
