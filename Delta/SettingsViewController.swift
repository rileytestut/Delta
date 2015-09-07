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
    case Controllers
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
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("externalControllerDidConnect:"), name: ExternalControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("externalControllerDidDisconnect:"), name: ExternalControllerDidDisconnectNotification, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if segue.identifier == SettingsSegues.Controllers.rawValue
        {
            let controllersSettingsViewController = segue.destinationViewController as! ControllersSettingsViewController
            controllersSettingsViewController.playerIndex = self.tableView.indexPathForSelectedRow?.row
        }
    }
}

private extension SettingsViewController
{
    @IBAction func unwindControllersSettingsViewController(segue: UIStoryboardSegue)
    {
        let indexPath = self.tableView.indexPathForSelectedRow
        
        self.tableView.reloadSections(NSIndexSet(index: SettingsSection.Controllers.rawValue), withRowAnimation: .None)
        
        self.tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: UITableViewScrollPosition.None)
    }
}

private extension SettingsViewController
{
    dynamic func externalControllerDidConnect(notification: NSNotification)
    {
        self.tableView.reloadSections(NSIndexSet(index: SettingsSection.Controllers.rawValue), withRowAnimation: .None)
    }
    
    dynamic func externalControllerDidDisconnect(notification: NSNotification)
    {
        self.tableView.reloadSections(NSIndexSet(index: SettingsSection.Controllers.rawValue), withRowAnimation: .None)
    }
}

extension SettingsViewController
{
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        
        if indexPath.section == SettingsSection.Controllers.rawValue
        {
            if indexPath.row == Settings.localControllerPlayerIndex
            {
                cell.detailTextLabel?.text = UIDevice.currentDevice().name
            }
            else if let index = ExternalControllerManager.sharedManager.connectedControllers.indexOf({ $0.playerIndex == indexPath.row })
            {
                let controller = ExternalControllerManager.sharedManager.connectedControllers[index]
                cell.detailTextLabel?.text = controller.name
            }
            else
            {
                cell.detailTextLabel?.text = nil
            }
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        if indexPath.section == SettingsSection.Controllers.rawValue
        {
            self.performSegueWithIdentifier(SettingsSegues.Controllers.rawValue, sender: self)
        }
    }
}
