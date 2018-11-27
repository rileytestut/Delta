//
//  RecordSyncStatusViewController.swift
//  Delta
//
//  Created by Riley Testut on 11/20/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

import Harmony

extension RecordStatus
{
    fileprivate var localizedDescription: String {
        switch self
        {
        case .normal: return NSLocalizedString("Normal", comment: "")
        case .updated: return NSLocalizedString("Updated", comment: "")
        case .deleted: return NSLocalizedString("Deleted", comment: "")
        }
    }
}

extension RecordSyncStatusViewController
{
    private enum Section: Int, CaseIterable
    {
        case syncingEnabled
        case localStatus
        case remoteStatus
        case versions
    }
}

class RecordSyncStatusViewController: UITableViewController
{
    var recordedObject: SyncableManagedObject!
    var record: Record<NSManagedObject>?
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .short
        
        return dateFormatter
    }()
    
    @IBOutlet private var syncingEnabledSwitch: UISwitch!
    
    @IBOutlet private var localStatusLabel: UILabel!
    @IBOutlet private var localDateLabel: UILabel!
    
    @IBOutlet private var remoteStatusLabel: UILabel!
    @IBOutlet private var remoteDateLabel: UILabel!
    @IBOutlet private var remoteDeviceLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.update()
        self.tableView.reloadData()
    }
}

private extension RecordSyncStatusViewController
{
    func update()
    {
        do
        {
            let records = try SyncManager.shared.recordController.fetchRecords(for: [self.recordedObject])
            self.record = records.first
        }
        catch
        {
            print(error)
        }
        
        if let record = self.record
        {
            self.syncingEnabledSwitch.isEnabled = !record.isConflicted
            self.syncingEnabledSwitch.isOn = record.isSyncingEnabled
            
            self.localStatusLabel.text = record.localStatus?.localizedDescription ?? "-"
            self.remoteStatusLabel.text = record.remoteStatus?.localizedDescription ?? "-"
            
            self.remoteDeviceLabel.text = record.remoteAuthor ?? "-"
            
            if let version = record.remoteVersion
            {
                self.remoteDateLabel.text = self.dateFormatter.string(from: version.date)
            }
            else
            {
                self.remoteDateLabel.text = "-"
            }
        }
        else
        {
            self.syncingEnabledSwitch.isEnabled = false
            self.syncingEnabledSwitch.isOn = false
            
            self.localStatusLabel.text = "-"
            self.localDateLabel.text = "-"
            
            self.remoteStatusLabel.text = "-"
            self.remoteDateLabel.text = "-"
            self.remoteDeviceLabel.text = "-"
        }
    }
    
    @IBAction func toggleSyncingEnabled(_ sender: UISwitch)
    {
        do
        {
            try self.record?.setSyncingEnabled(sender.isOn)
        }
        catch
        {
            let title = sender.isOn ? NSLocalizedString("Failed to Enable Syncing", comment: "") : NSLocalizedString("Failed to Disable Syncing", comment: "")
            
            let alertController = UIAlertController(title: title, error: error)
            self.present(alertController, animated: true, completion: nil)
        }
        
        self.update()
    }
}

extension RecordSyncStatusViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .versions:
            cell.textLabel?.alpha = (self.record != nil) ? 1.0 : 0.33
            
            if self.record?.isConflicted == true
            {
                cell.textLabel?.text = NSLocalizedString("Resolve Conflict", comment: "")
                cell.textLabel?.textColor = .red
            }
            else
            {
                cell.textLabel?.text = NSLocalizedString("View Versions", comment: "")
                cell.textLabel?.textColor = .deltaPurple
            }
            
        default: break
        }
        
        return cell
    }
}
