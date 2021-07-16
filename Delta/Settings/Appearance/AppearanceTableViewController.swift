//
//  AppearanceTableViewController.swift
//  Delta
//
//  Created by Ian Clawson on 7/14/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit

enum PageControlIndicatorType: String, CaseIterable
{
    case standard = "standard"
    case cartridge = "cartridge"
    case controller = "controller"
    
    func displayName() -> String
    {
        switch self
        {
        case .standard: return "Standard"
        case .cartridge: return "Cartridge"
        case .controller:  return "Controller"
        }
    }
    
    func image(for system: System) -> UIImage?
    {
        switch self
        {
        case .standard: return nil
        case .cartridge: return UIImage(named: "PCG_Cartridge_\(system.localizedShortName)")
        case .controller:  return UIImage(named: "PCG_Controller_\(system.localizedShortName)")
        }
    }
}

extension AppearanceTableViewController
{
    enum Section: Int, CaseIterable
    {
        case appIcon
        case appColor
        enum AppColorRow: Int, CaseIterable
        {
            case configure
            case resetDefault
        }
        case pageControlIndicator
    }
    
}

extension Notification.Name
{
    static let pageControlIndicatorDidChange = Notification.Name("AppearancePageControlIndicatorDidChangeNotification")
}

class AppearanceTableViewController: UITableViewController
{
    var newThemeColor: UIColor?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = "Appearance"
    }
    
    func setNewThemeColor(_ newColor: UIColor)
    {
        Settings.themeColor = newColor
        NotificationCenter.default.post(name: .pageControlIndicatorDidChange, object: nil, userInfo: nil)
    }
}

extension AppearanceTableViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var sectionCount = 0
        
        for section in Section.allCases
        {
            if isSectionHidden(section) == false
            {
                sectionCount += 1
            }
        }
        
        return sectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        guard
            let section = Section(rawValue: section),
            isSectionHidden(section) == false
        else { return 0 }
        
        switch section
        {
        case .appIcon: return 1
        case .appColor: return Section.AppColorRow.allCases.count
        case .pageControlIndicator: return PageControlIndicatorType.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        
        var reuseIdentifier: String
        switch section
        {
        case .appIcon: reuseIdentifier = "ChangeAppIconRow"
        case .appColor: reuseIdentifier = "ChangeAppColorRow"
        case .pageControlIndicator: reuseIdentifier = "ChangePageControlIndicatorRow"
        }
        
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: reuseIdentifier)
        }
        
        switch section
        {
        case .appIcon:
            cell?.textLabel?.text = "Change App Icon"
            cell?.accessoryType = .disclosureIndicator
        case .appColor:
            if let row = Section.AppColorRow(rawValue: indexPath.row)
            {
                switch row
                {
                case .configure:
                    cell?.textLabel?.text = "Open Color Picker"
                    cell?.textLabel?.textColor = nil
                    cell?.accessoryType = .disclosureIndicator
                case .resetDefault:
                    cell?.textLabel?.text = "Reset to Default"
                    cell?.textLabel?.textColor = UIColor.deltaPurple
                    cell?.accessoryType = .disclosureIndicator
                }
            }
        case .pageControlIndicator:
            let selectedType = PageControlIndicatorType.allCases[indexPath.row]
            let gamesPageControlIndicatorType = Settings.gamesPageControlIndicatorType ?? .standard
            cell?.textLabel?.text = selectedType.displayName()
            cell?.accessoryType = (selectedType == gamesPageControlIndicatorType) ? .checkmark : .none
        }
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.beginUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.endUpdates()
    
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section
        {
        case .appIcon:
            let vc = AppIconsViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        case .appColor:
            if let row = Section.AppColorRow(rawValue: indexPath.row)
            {
                if #available(iOS 14.0, *)
                {
                    switch row
                    {
                    case .configure:
                        let colorPicker = UIColorPickerViewController()
                        colorPicker.delegate = self
                        colorPicker.supportsAlpha = false
                        colorPicker.selectedColor = Settings.themeColor
                        present(colorPicker, animated: true, completion: nil)
                    case .resetDefault:
                        self.setNewThemeColor(UIColor.deltaPurple)
                        let alertController = UIAlertController(title: NSLocalizedString("Color Reset", comment: ""), message: nil, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self.present(alertController, animated: true, completion: nil)
                    }
                }
            }
        case .pageControlIndicator:
            let selectedType = PageControlIndicatorType.allCases[indexPath.row]
            guard
                let gamesPageControlIndicatorType = Settings.gamesPageControlIndicatorType,
                selectedType != gamesPageControlIndicatorType
            else { return }
            
            Settings.gamesPageControlIndicatorType = selectedType
            
            NotificationCenter.default.post(name: .pageControlIndicatorDidChange, object: nil, userInfo: nil)
            
            self.tableView.reloadSections(IndexSet(integer: Section.pageControlIndicator.rawValue), with: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard
            let section = Section(rawValue: section),
            isSectionHidden(section) == false
        else { return nil }
        
        switch section
        {
        case .appIcon: return "App Icon"
        case .appColor: return "App Color"
        case .pageControlIndicator: return "Page Indicator Symbol"
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        guard
            let section = Section(rawValue: section),
            isSectionHidden(section) == false
        else { return nil }
        
        switch section
        {
        case .appIcon: return "Choose your favorite App Icon to display on the home screen."
        case .appColor: return "Change the primary accent color used throughout Delta."
        case .pageControlIndicator: return "Configure the symbol used for the Page Control element on the Game selection screen."
        }
    }
    
    func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
        case .appColor, .pageControlIndicator:
            if #available(iOS 14.0, *)
            {
                return false
            }
            else
            {
                return true
            }
        default:
            return false
        }
    }
}

@available(iOS 14.0, *)
extension AppearanceTableViewController: UIColorPickerViewControllerDelegate
{
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController)
    {
        self.newThemeColor = viewController.selectedColor
    }

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController)
    {
        if let newThemeColor = self.newThemeColor
        {
            self.setNewThemeColor(newThemeColor)
            self.newThemeColor = nil
        }
    }
}
