//
//  SyncingServicesViewController.swift
//  Delta
//
//  Created by Riley Testut on 6/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

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
        case signOut
    }
}

class SyncingServicesViewController: UITableViewController
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
            
        case .account, .signOut: break
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
                self.tableView.deleteSections(IndexSet(integersIn: Section.account.rawValue ... Section.signOut.rawValue), with: .fade)
            }
            else if Settings.syncingService != .none && self.tableView.numberOfSections == 1
            {
                self.tableView.insertSections(IndexSet(integersIn: Section.account.rawValue ... Section.signOut.rawValue), with: .fade)
            }
            
            self.tableView.reloadSections(IndexSet(integer: Section.service.rawValue), with: .none)
            
        case .account, .signOut: break
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        switch Section.allCases[indexPath.section]
        {
        case .service: return super.tableView(tableView, heightForRowAt: indexPath)
        case .account, .signOut: return (Settings.syncingService == .none) ? 0 : super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
