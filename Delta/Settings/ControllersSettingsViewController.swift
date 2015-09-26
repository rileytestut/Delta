//
//  ControllersSettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore

private enum ControllersSettingsSection: Int
{
    case None
    case LocalDevice
    case ExternalControllers
}

private class LocalDeviceController: ExternalController
{
    override var name: String {
        return UIDevice.currentDevice().name
    }
}

class ControllersSettingsViewController: UITableViewController
{
    var playerIndex: Int? {
        didSet
        {
            if let playerIndex = self.playerIndex
            {
                self.title = NSLocalizedString("Player \(playerIndex + 1)", comment: "")
            }
            else
            {
                self.title = NSLocalizedString("Controllers", comment: "")
            }
        }
    }
    
    private var connectedControllers = ExternalControllerManager.sharedManager.connectedControllers.sort({ $0.playerIndex ?? NSIntegerMax < $1.playerIndex ?? NSIntegerMax })
    
    private lazy var localDeviceController: LocalDeviceController = {
        let device = LocalDeviceController()
        device.playerIndex = Settings.localControllerPlayerIndex
        
        return device
    }()
    
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
    
    //MARK: - Storyboards -
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
        
        var controllers = self.connectedControllers
        controllers.append(self.localDeviceController)

        // Reset previous controller
        if let playerIndex = self.playerIndex, index = controllers.indexOf({ $0.playerIndex == playerIndex })
        {
            let controller = controllers[index]
            controller.playerIndex = nil
        }
        
        switch ControllersSettingsSection(rawValue: indexPath.section)!
        {
        case .None: break
        case .LocalDevice: self.localDeviceController.playerIndex = self.playerIndex
        case .ExternalControllers:
            let controller = self.connectedControllers[indexPath.row]
            controller.playerIndex = self.playerIndex
        }
        
        // Updates in case we reset it above, as well as if we updated in the switch statement
        Settings.localControllerPlayerIndex = self.localDeviceController.playerIndex
    }
}

private extension ControllersSettingsViewController
{
    dynamic func externalControllerDidConnect(notification: NSNotification)
    {
        guard let controller = notification.object as? ExternalController else { return }
        
        if let playerIndex = controller.playerIndex
        {
            self.connectedControllers.insert(controller, atIndex: playerIndex)
        }
        else
        {
            self.connectedControllers.append(controller)
        }
        
        if let index = self.connectedControllers.indexOf(controller)
        {
            if self.connectedControllers.count == 1
            {
                self.tableView.insertSections(NSIndexSet(index: ControllersSettingsSection.ExternalControllers.rawValue), withRowAnimation: .Fade)
            }
            else
            {
                self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: ControllersSettingsSection.ExternalControllers.rawValue)], withRowAnimation: .Automatic)
            }
        }
    }
    
    dynamic func externalControllerDidDisconnect(notification: NSNotification)
    {
        guard let controller = notification.object as? ExternalController else { return }
        
        if let index = self.connectedControllers.indexOf(controller)
        {
            self.connectedControllers.removeAtIndex(index)
            
            if self.connectedControllers.count == 0
            {
                self.tableView.deleteSections(NSIndexSet(index: ControllersSettingsSection.ExternalControllers.rawValue), withRowAnimation: .Fade)
            }
            else
            {
                self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: ControllersSettingsSection.ExternalControllers.rawValue)], withRowAnimation: .Automatic)
            }
        }
        
        if controller.playerIndex == self.playerIndex
        {
            self.tableView.reloadSections(NSIndexSet(index: ControllersSettingsSection.None.rawValue), withRowAnimation: .None)
        }
    }
}

extension ControllersSettingsViewController
{
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        if self.connectedControllers.count == 0
        {
            return 2
        }

        return 3
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch ControllersSettingsSection(rawValue: section)!
        {
        case .None: return 1
        case .LocalDevice: return 1
        case .ExternalControllers: return self.connectedControllers.count
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .None
        
        if indexPath.section == ControllersSettingsSection.None.rawValue
        {
            cell.textLabel?.text = NSLocalizedString("None", comment: "")
            
            if Settings.localControllerPlayerIndex != self.playerIndex && !self.connectedControllers.contains({ $0.playerIndex == self.playerIndex })
            {
                cell.accessoryType = .Checkmark
            }
        }
        else
        {
            let controller: ExternalController
            
            if indexPath.section == ControllersSettingsSection.LocalDevice.rawValue
            {
                controller = self.localDeviceController
            }
            else if indexPath.section == ControllersSettingsSection.ExternalControllers.rawValue
            {
                controller = self.connectedControllers[indexPath.row]
            }
            else
            {
                fatalError("Section index invalid")
            }
            
            cell.textLabel?.text = controller.name
            
            if controller.playerIndex == self.playerIndex
            {
                cell.accessoryType = .Checkmark
            }
            else
            {
                if let playerIndex = controller.playerIndex
                {
                    cell.detailTextLabel?.text = NSLocalizedString("Player \(playerIndex + 1)", comment: "")
                }
                
            }
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch ControllersSettingsSection(rawValue: section)!
        {
        case .None: return nil
        case .LocalDevice: return NSLocalizedString("Local Device", comment: "")
        case .ExternalControllers: return self.connectedControllers.count > 0 ? NSLocalizedString("External Controllers", comment: "") : ""
        }
    }
}
