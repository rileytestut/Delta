//
//  AppIconsViewController.swift
//  Delta
//
//  Created by Ian Clawson on 6/24/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit

extension AppIconsViewController
{
    enum Section: Int, CaseIterable
    {
        case bgColors
        case fgColors
        case original
        
        func rows() -> [AppIconData]
        {
            switch self
            {
            case .bgColors: return [.bgPurple, .bgBlue, .bgGreen, .bgOrange, .bgRed, .bgPride1, .bgPride2]
            case .fgColors: return [.fgPurple, .fgBlue, .fgGreen, .fgOrange, .fgRed, .fgPride1, .fgPride2]
            case .original: return [.delta64Light, .delta64Dark]
            }
        }
    }
    
    enum AppIconData: Int, CaseIterable
    {
        case bgPurple
        case bgBlue
        case bgGreen
        case bgOrange
        case bgRed
        case bgPride1
        case bgPride2
        
        case fgPurple
        case fgBlue
        case fgGreen
        case fgOrange
        case fgRed
        case fgPride1
        case fgPride2
        
        case delta64Light
        case delta64Dark
        
        func displayTitle() -> String
        {
            switch self
            {
            case .bgPurple: return "Delta"
            case .bgBlue: return "Blue"
            case .bgGreen: return "Green"
            case .bgOrange: return "Orange"
            case .bgRed: return "Red"
            case .bgPride1: return "Pride 1"
            case .bgPride2: return "Pride 2"
                
            case .fgPurple: return "GBA4iOS"
            case .fgBlue: return "Blue"
            case .fgGreen: return "Green"
            case .fgOrange: return "Orange"
            case .fgRed: return "Red"
            case .fgPride1: return "Pride 1"
            case .fgPride2: return "Pride 2"
                
            case .delta64Light: return "Delta64 Light"
            case .delta64Dark: return "Delta64 Dark"
            }
        }
        
        func key() -> String
        {
            switch self
            {
            case .bgPurple: return "bg_purple"
            case .bgBlue: return "bg_blue"
            case .bgGreen: return "bg_green"
            case .bgOrange: return "bg_orange"
            case .bgRed: return "bg_red"
            case .bgPride1: return "bg_pride_1"
            case .bgPride2: return "bg_pride_2"
                
            case .fgPurple: return "fg_purple"
            case .fgBlue: return "fg_blue"
            case .fgGreen: return "fg_green"
            case .fgOrange: return "fg_orange"
            case .fgRed: return "fg_red"
            case .fgPride1: return "fg_pride_1"
            case .fgPride2: return "fg_pride_2"
                
            case .delta64Light: return "delta64_light"
            case .delta64Dark: return "delta64_dark"
            }
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
        
        guard
            let section = Section(rawValue: indexPath.section),
            let icon = section.rows()[safe: indexPath.row]
        else { return }
        
        DispatchQueue.main.async
        {
            print("icon.key():\(icon.key())")
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
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        guard let section = Section(rawValue: section) else { return 0 }
        return section.rows().count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard
            let section = Section(rawValue: indexPath.section),
            let icon = section.rows()[safe: indexPath.row]
        else { return UITableViewCell() }
        
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
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard let section = Section(rawValue: section) else { return nil }
        
        switch section
        {
        case .bgColors: return "Background Colors"
        case .fgColors: return "Foreground Colors"
        case .original: return "Original Icons"
        }
    }
    
}

public extension Collection
{
    subscript (safe index: Index) -> Element?
    {
        return indices.contains(index) ? self[index] : nil
    }
}
