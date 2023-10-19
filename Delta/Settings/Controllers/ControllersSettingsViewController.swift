//
//  ControllersSettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 8/23/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore

import Roxas

extension ControllersSettingsViewController
{
    private enum Section: Int
    {
        case none
        case localDevice
        case externalControllers
        case customizeControls
    }
}

private class LocalDeviceController: NSObject, GameController
{
    var name: String {
        return UIDevice.current.name
    }
    
    var playerIndex: Int? {
        set { Settings.localControllerPlayerIndex = newValue }
        get { return Settings.localControllerPlayerIndex }
    }
    
    let inputType: GameControllerInputType = .standard
    
    var defaultInputMapping: GameControllerInputMappingProtocol?
}

class ControllersSettingsViewController: UITableViewController
{
    var playerIndex: Int! {
        didSet {
            self.title = NSLocalizedString("Player \(self.playerIndex + 1)", comment: "")
        }
    }
    
    private var gameController: GameController? {
        didSet {
            // Order matters since localDeviceController changes Settings.localControllerPlayerIndex, which sends out NSNotification.
            if oldValue == self.localDeviceController
            {
                self.gameController?.playerIndex = self.playerIndex
                oldValue?.playerIndex = nil
            }
            else
            {
                // Ensure it's still a discovered controller, or else it might crash when setting player index.
                if ExternalGameControllerManager.shared.connectedControllers.contains(where: { $0 === oldValue })
                {
                    oldValue?.playerIndex = nil
                }
                
                self.gameController?.playerIndex = self.playerIndex
            }
        }
    }
    
    private var connectedControllers = ExternalGameControllerManager.shared.connectedControllers.sorted(by: { $0.playerIndex ?? NSIntegerMax < $1.playerIndex ?? NSIntegerMax })
    
    private lazy var localDeviceController: LocalDeviceController = {
        let device = LocalDeviceController()
        device.playerIndex = Settings.localControllerPlayerIndex
        
        return device
    }()
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ControllersSettingsViewController.externalGameControllerDidConnect(_:)), name: .externalGameControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ControllersSettingsViewController.externalGameControllerDidDisconnect(_:)), name: .externalGameControllerDidDisconnect, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let gameControllers = [self.localDeviceController as GameController] + self.connectedControllers
        for gameController in gameControllers
        {
            if gameController.playerIndex == self.playerIndex
            {
                self.gameController = gameController
                break
            }
        }
    }
}

extension ControllersSettingsViewController
{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "controllerInputsSegue":
            let navigationController = segue.destination as! UINavigationController
            
            let controllerInputsViewController = navigationController.topViewController as! ControllerInputsViewController
            controllerInputsViewController.gameController = self.gameController
            
            if self.view.traitCollection.userInterfaceIdiom == .pad
            {
                // For now, only iPads can display ControllerInputsViewController as a form sheet.
                navigationController.modalPresentationStyle = .formSheet
                navigationController.presentationController?.delegate = controllerInputsViewController
            }
            
        default: break
        }
        
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    @IBAction private func unwindFromControllerInputsViewController(_ segue: UIStoryboardSegue)
    {
    }
}

private extension ControllersSettingsViewController
{
    func configure(_ cell: UITableViewCell, for indexPath: IndexPath)
    {
        cell.accessoryType = .none
        cell.detailTextLabel?.text = nil
        
        if #available(iOS 13.0, *) {
            cell.textLabel?.textColor = .label
        } else {
            cell.textLabel?.textColor = .darkText
        }
        
        switch Section(rawValue: indexPath.section)!
        {
        case .none:
            cell.textLabel?.text = NSLocalizedString("None", comment: "")
            
            if self.gameController == nil
            {
                cell.accessoryType = .checkmark
            }
            else
            {
                cell.accessoryType = .none
            }
            
        case .localDevice, .externalControllers:
            let controller: GameController
            
            if indexPath.section == Section.localDevice.rawValue
            {
                controller = self.localDeviceController
            }
            else if indexPath.section == Section.externalControllers.rawValue
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
                cell.accessoryType = .checkmark
            }
            else
            {
                cell.accessoryType = .none
            }
            
        case .customizeControls:
            cell.textLabel?.text = NSLocalizedString("Customize Controls…", comment: "")
            cell.textLabel?.textColor = self.view.tintColor
        }
    }
}

private extension ControllersSettingsViewController
{
    @objc func externalGameControllerDidConnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GameController else { return }
        
        if let playerIndex = controller.playerIndex
        {
            // Keep connected controllers sorted.
            
            self.connectedControllers.insert(controller, at: playerIndex)
        }
        else
        {
            self.connectedControllers.append(controller)
        }
        
        self.tableView.beginUpdates()
        
        if let index = self.connectedControllers.firstIndex(where: { $0 == controller })
        {
            if self.connectedControllers.count == 1 && self.connectedControllers.first?.playerIndex == self.playerIndex
            {
                self.tableView.deleteRows(at: [IndexPath(row: 0, section: Section.externalControllers.rawValue)], with: .automatic)
            }
            
            self.tableView.insertRows(at: [IndexPath(row: index, section: Section.externalControllers.rawValue)], with: .automatic)
        }
        
        if controller.playerIndex == self.playerIndex
        {
            self.gameController = controller
            
            self.tableView.reloadSections(IndexSet(integer: Section.localDevice.rawValue), with: .none)
            self.tableView.insertSections(IndexSet(integer: Section.customizeControls.rawValue), with: .none)
        }
        
        self.tableView.endUpdates()
    }
    
    @objc func externalGameControllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GameController else { return }
        
        self.tableView.beginUpdates()
        
        if let index = self.connectedControllers.firstIndex(where: { $0 == controller })
        {
            self.connectedControllers.remove(at: index)
            
            if self.connectedControllers.count == 0 && controller.playerIndex != nil
            {
                self.tableView.insertRows(at: [IndexPath(row: 0, section: Section.externalControllers.rawValue)], with: .automatic)
            }
            
            self.tableView.deleteRows(at: [IndexPath(row: index, section: Section.externalControllers.rawValue)], with: .automatic)
        }
        
        if controller.playerIndex == self.playerIndex
        {
            self.gameController = self.localDeviceController
            
            self.tableView.reloadSections(IndexSet(integer: Section.localDevice.rawValue), with: .none)
            self.tableView.deleteSections(IndexSet(integer: Section.customizeControls.rawValue), with: .none)
        }
        
        self.tableView.endUpdates()
    }
}

extension ControllersSettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        if self.gameController == self.localDeviceController || self.gameController == nil
        {
            return 3
        }

        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch Section(rawValue: section)!
        {
        case .none where self.playerIndex == 0: return 0
        case .none: return 1
        case .localDevice: return 1
        case .externalControllers: return self.connectedControllers.isEmpty ? 1 : self.connectedControllers.count
        case .customizeControls: return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .externalControllers where self.connectedControllers.isEmpty:
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoControllers", for: indexPath)
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: RSTCellContentGenericCellIdentifier, for: indexPath)
            self.configure(cell, for: indexPath)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch Section(rawValue: section)!
        {
        case .none: return nil
        case .localDevice: return NSLocalizedString("This Device", comment: "")
        case .externalControllers: return NSLocalizedString("Game Controllers", comment: "")
        case .customizeControls: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        switch Section(rawValue: section)!
        {
        case .none where self.playerIndex == 0: return 1
        default: return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        switch Section(rawValue: section)!
        {
        case .none where self.playerIndex == 0: return 1
        default: return UITableView.automaticDimension
        }
    }
}

extension ControllersSettingsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let previousGameController = self.gameController
        
        switch Section(rawValue: indexPath.section)!
        {
        case .none: self.gameController = nil
        case .localDevice: self.gameController = self.localDeviceController
        case .externalControllers where self.connectedControllers.isEmpty: return
        case .externalControllers: self.gameController = self.connectedControllers[indexPath.row]
        case .customizeControls:
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            self.performSegue(withIdentifier: "controllerInputsSegue", sender: cell)
            
            return
        }
        
        let previousIndexPath: IndexPath?
        
        if let gameController = previousGameController
        {
            if gameController == self.localDeviceController
            {
                previousIndexPath = IndexPath(row: 0, section: Section.localDevice.rawValue)
            }
            else if let row = self.connectedControllers.firstIndex(where: { $0 == gameController })
            {
                previousIndexPath = IndexPath(row: row, section: Section.externalControllers.rawValue)
            }
            else
            {
                previousIndexPath = nil
            }
        }
        else
        {
            previousIndexPath = IndexPath(row: 0, section: Section.none.rawValue)
        }
        
        self.tableView.beginUpdates()
        
        if let previousIndexPath = previousIndexPath, let cell = tableView.cellForRow(at: previousIndexPath)
        {
            // Must configure cell directly, or else a strange animation occurs when reloading row on iOS 11.
            self.configure(cell, for: previousIndexPath)
        }
        
        self.tableView.reloadRows(at: [indexPath], with: .none)

        if self.numberOfSections(in: self.tableView) > self.tableView.numberOfSections
        {
            self.tableView.insertSections(IndexSet(integer: Section.customizeControls.rawValue), with: .fade)
        }
        else if self.numberOfSections(in: self.tableView) < self.tableView.numberOfSections
        {
            self.tableView.deleteSections(IndexSet(integer: Section.customizeControls.rawValue), with: .fade)
        }
        
        self.tableView.endUpdates()
    }
}
