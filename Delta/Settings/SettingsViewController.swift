//
//  SettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore

private enum SettingsSection: Int
{
    case controllers
}

private enum SettingsSegues: String
{
    case Controllers = "controllersSegue"
}

class SettingsViewController: UITableViewController
{
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalControllerDidConnect(_:)), name: .externalControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalControllerDidDisconnect(_:)), name: .externalControllerDidDisconnect, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if segue.identifier == SettingsSegues.Controllers.rawValue
        {
            let controllersSettingsViewController = segue.destinationViewController as! ControllersSettingsViewController
            controllersSettingsViewController.playerIndex = (self.tableView.indexPathForSelectedRow as NSIndexPath?)?.row
        }
    }
}

private extension SettingsViewController
{
    @IBAction func unwindFromControllersSettingsViewController(_ segue: UIStoryboardSegue)
    {
        let indexPath = self.tableView.indexPathForSelectedRow
        
        self.tableView.reloadSections(IndexSet(integer: SettingsSection.controllers.rawValue), with: .none)
        
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
    }
}

private extension SettingsViewController
{
    dynamic func externalControllerDidConnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: SettingsSection.controllers.rawValue), with: .none)
    }
    
    dynamic func externalControllerDidDisconnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: SettingsSection.controllers.rawValue), with: .none)
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        if (indexPath as NSIndexPath).section == SettingsSection.controllers.rawValue
        {
            if (indexPath as NSIndexPath).row == Settings.localControllerPlayerIndex
            {
                cell.detailTextLabel?.text = UIDevice.current().name
            }
            else if let index = ExternalControllerManager.shared.connectedControllers.index(where: { $0.playerIndex == (indexPath as NSIndexPath).row })
            {
                let controller = ExternalControllerManager.shared.connectedControllers[index]
                cell.detailTextLabel?.text = controller.name
            }
            else
            {
                cell.detailTextLabel?.text = nil
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if (indexPath as NSIndexPath).section == SettingsSection.controllers.rawValue
        {
            self.performSegue(withIdentifier: SettingsSegues.Controllers.rawValue, sender: self)
        }
    }
}
