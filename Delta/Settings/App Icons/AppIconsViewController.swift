//
//  AppIconsViewController.swift
//  Delta
//
//  Created by Kyle Grieder on 10/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class AppIconsViewController: UITableViewController {
    
    let application = UIApplication.shared
    
    private let icons: Array = [
        AppIcon(name: "Delta", assetName: .DeltaDefault),
        AppIcon(name: "Orange", assetName: .DeltaOrange),
        AppIcon(name: "Blue", assetName: .DeltaBlue),
        AppIcon(name: "Red", assetName: .DeltaRed),
        AppIcon(name: "Green", assetName: .DeltaGreen),
        AppIcon(name: "Delta4iOS", assetName: .Delta4iOS),
        AppIcon(name: "Orange4iOS", assetName: .Orange4iOS),
        AppIcon(name: "Blue4iOS", assetName: .Blue4iOS),
        AppIcon(name: "Red4iOS", assetName: .Red4iOS),
        AppIcon(name: "Green4iOS", assetName: .Green4iOS),
        AppIcon(name: "Delta64", assetName: .Delta64),
        AppIcon(name: "Delta64 Dark", assetName: .Delta64Dark),
        AppIcon(name: "Nintendo", assetName: .Nintendo),
        AppIcon(name: "Nes", assetName: .Nes),
        AppIcon(name: "Snes", assetName: .Snes),
        AppIcon(name: "N64", assetName: .N64),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let icon = self.icons[indexPath.row]
        var name: String? = nil
        
        if (icon.assetName != AppIcon.AssetName.DeltaDefault.rawValue) {
            name = icon.assetName
        }
        
        application.setAlternateIconName(name) { (error) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
        
        self.tableView.deselectRow(at: indexPath, animated: true)
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return self.icons.count
        case 2:
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.row == self.icons.count + 1) {
            let cell = UITableViewCell()
            cell.textLabel?.text = "Console Icons from Icons8.com"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: AppIconCell.reuseIdentifier, for: indexPath) as! AppIconCell
        
        cell.iconLabel.text = self.icons[indexPath.row].name
        cell.iconImage.image = self.icons[indexPath.row].image
        
        let icon = self.icons[indexPath.row]
        if let selectedIcon = application.alternateIconName {
            cell.checkmark.isHidden = icon.assetName != selectedIcon
        } else {
            cell.checkmark.isHidden = icon.assetName != "DeltaDefault"
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Icons"
        case 2:
            return "Credits"
        default:
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }

}
