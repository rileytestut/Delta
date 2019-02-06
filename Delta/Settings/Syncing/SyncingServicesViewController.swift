//
//  SyncingServicesViewController.swift
//  Delta
//
//  Created by Riley Testut on 6/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Harmony
import Harmony_Drive

import Roxas

enum SyncingService: String, CaseIterable
{
    case none
    case googleDrive
    
    var localizedName: String {
        switch self
        {
        case .none: return NSLocalizedString("None", comment: "")
        case .googleDrive: return NSLocalizedString("Google Drive", comment: "")
        }
    }
}

extension SyncingServicesViewController
{
    enum Section: Int, CaseIterable
    {
        case service
        case account
        case authenticate
    }
}

class SyncingServicesViewController: UITableViewController
{
    func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
        case .account: return SyncManager.shared.syncCoordinator.account == nil
        default: return false
        }
    }
}

extension SyncingServicesViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        guard Settings.syncingService != .none else { return 1 }
        
        return super.numberOfSections(in: tableView)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .service:
            let service = SyncingService.allCases[indexPath.row]
            cell.accessoryType = (service == Settings.syncingService) ? .checkmark : .none
            
        case .account:
            cell.textLabel?.text = SyncManager.shared.syncCoordinator.account?.name ?? NSLocalizedString("Unknown Account", comment: "")
            
        case .authenticate:
            if SyncManager.shared.syncCoordinator.isAuthenticated
            {
                cell.textLabel?.textColor = .red
                cell.textLabel?.text = NSLocalizedString("Sign Out", comment: "")
            }
            else
            {
                cell.textLabel?.textColor = .deltaPurple
                cell.textLabel?.text = NSLocalizedString("Sign In", comment: "")
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch Section.allCases[indexPath.section]
        {
        case .service:
            Settings.syncingService = SyncingService.allCases[indexPath.row]
            
            if Settings.syncingService == .none && self.tableView.numberOfSections > 1
            {
                self.tableView.deleteSections(IndexSet(integersIn: Section.account.rawValue ... Section.authenticate.rawValue), with: .fade)
            }
            else if Settings.syncingService != .none && self.tableView.numberOfSections == 1
            {
                self.tableView.insertSections(IndexSet(integersIn: Section.account.rawValue ... Section.authenticate.rawValue), with: .fade)
            }
            
            self.tableView.reloadSections(IndexSet(integer: Section.service.rawValue), with: .none)
            
        case .account: break
            
        case .authenticate:
            if SyncManager.shared.syncCoordinator.isAuthenticated
            {
                SyncManager.shared.syncCoordinator.deauthenticate { (result) in
                    DispatchQueue.main.async {
                        do
                        {
                            try result.verify()
                            self.tableView.reloadData()
                        }
                        catch
                        {
                            let alertController = UIAlertController(title: NSLocalizedString("Failed to Sign Out", comment: ""), error: error)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
            else
            {
                SyncManager.shared.syncCoordinator.authenticate(presentingViewController: self) { (result) in
                    DispatchQueue.main.async {
                        do
                        {
                            try result.verify()
                            self.tableView.reloadData()
                        }
                        catch
                        {
                            
                            let alertController = UIAlertController(title: NSLocalizedString("Failed to Sign In", comment: ""), error: error)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 0
        }
        else
        {
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return nil
        }
        else
        {
            return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
}
