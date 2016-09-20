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
    case none
    case localDevice
    case externalControllers
}

private class LocalDeviceController: ExternalController
{
    override var name: String {
        return UIDevice.current.name
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
    
    fileprivate var connectedControllers = ExternalControllerManager.shared.connectedControllers.sorted(by: { $0.playerIndex ?? NSIntegerMax < $1.playerIndex ?? NSIntegerMax })
    
    fileprivate lazy var localDeviceController: LocalDeviceController = {
        let device = LocalDeviceController()
        device.playerIndex = Settings.localControllerPlayerIndex
        
        return device
    }()
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ControllersSettingsViewController.externalControllerDidConnect(_:)), name: .externalControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ControllersSettingsViewController.externalControllerDidDisconnect(_:)), name: .externalControllerDidDisconnect, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
    }
    
    //MARK: - Storyboards -
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
        
        var controllers = self.connectedControllers
        controllers.append(self.localDeviceController)

        // Reset previous controller
        if let playerIndex = self.playerIndex, let index = controllers.index(where: { $0.playerIndex == playerIndex })
        {
            let controller = controllers[index]
            controller.playerIndex = nil
        }
        
        switch ControllersSettingsSection(rawValue: (indexPath as NSIndexPath).section)!
        {
        case .none: break
        case .localDevice: self.localDeviceController.playerIndex = self.playerIndex
        case .externalControllers:
            let controller = self.connectedControllers[(indexPath as NSIndexPath).row]
            controller.playerIndex = self.playerIndex
        }
        
        // Updates in case we reset it above, as well as if we updated in the switch statement
        Settings.localControllerPlayerIndex = self.localDeviceController.playerIndex
    }
}

private extension ControllersSettingsViewController
{
    dynamic func externalControllerDidConnect(_ notification: Notification)
    {
        guard let controller = notification.object as? ExternalController else { return }
        
        if let playerIndex = controller.playerIndex
        {
            self.connectedControllers.insert(controller, at: playerIndex)
        }
        else
        {
            self.connectedControllers.append(controller)
        }
        
        if let index = self.connectedControllers.index(of: controller)
        {
            if self.connectedControllers.count == 1
            {
                self.tableView.insertSections(IndexSet(integer: ControllersSettingsSection.externalControllers.rawValue), with: .fade)
            }
            else
            {
                self.tableView.insertRows(at: [IndexPath(row: index, section: ControllersSettingsSection.externalControllers.rawValue)], with: .automatic)
            }
        }
    }
    
    dynamic func externalControllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? ExternalController else { return }
        
        if let index = self.connectedControllers.index(of: controller)
        {
            self.connectedControllers.remove(at: index)
            
            if self.connectedControllers.count == 0
            {
                self.tableView.deleteSections(IndexSet(integer: ControllersSettingsSection.externalControllers.rawValue), with: .fade)
            }
            else
            {
                self.tableView.deleteRows(at: [IndexPath(row: index, section: ControllersSettingsSection.externalControllers.rawValue)], with: .automatic)
            }
        }
        
        if controller.playerIndex == self.playerIndex
        {
            self.tableView.reloadSections(IndexSet(integer: ControllersSettingsSection.none.rawValue), with: .none)
        }
    }
}

extension ControllersSettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        if self.connectedControllers.count == 0
        {
            return 2
        }

        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch ControllersSettingsSection(rawValue: section)!
        {
        case .none: return 1
        case .localDevice: return 1
        case .externalControllers: return self.connectedControllers.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .none
        
        if (indexPath as NSIndexPath).section == ControllersSettingsSection.none.rawValue
        {
            cell.textLabel?.text = NSLocalizedString("None", comment: "")
            
            if Settings.localControllerPlayerIndex != self.playerIndex && !self.connectedControllers.contains(where: { $0.playerIndex == self.playerIndex })
            {
                cell.accessoryType = .checkmark
            }
        }
        else
        {
            let controller: ExternalController
            
            if (indexPath as NSIndexPath).section == ControllersSettingsSection.localDevice.rawValue
            {
                controller = self.localDeviceController
            }
            else if (indexPath as NSIndexPath).section == ControllersSettingsSection.externalControllers.rawValue
            {
                controller = self.connectedControllers[(indexPath as NSIndexPath).row]
            }
            else
            {
                fatalError("Section index invalid")
            }
            
            cell.textLabel?.text = controller.name
            
            if controller.playerIndex == self.playerIndex
            {
                cell.accessoryType = .checkmark
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
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch ControllersSettingsSection(rawValue: section)!
        {
        case .none: return nil
        case .localDevice: return NSLocalizedString("Local Device", comment: "")
        case .externalControllers: return self.connectedControllers.count > 0 ? NSLocalizedString("External Controllers", comment: "") : ""
        }
    }
}
