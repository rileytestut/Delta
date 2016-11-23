//
//  SettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore

extension SettingsViewController
{
    fileprivate enum Section: Int
    {
        case controllers
        case controllerSkins
        case controllerOpacity
    }
    
    fileprivate enum Segue: String
    {
        case controllers = "controllersSegue"
        case controllerSkins = "controllerSkinsSegue"
    }
}

class SettingsViewController: UITableViewController
{
    @IBOutlet fileprivate var controllerOpacityLabel: UILabel!
    @IBOutlet fileprivate var controllerOpacitySlider: UISlider!
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalControllerDidConnect(_:)), name: .externalControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalControllerDidDisconnect(_:)), name: .externalControllerDidDisconnect, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.controllerOpacitySlider.value = Float(Settings.translucentControllerSkinOpacity)
        self.updateControllerOpacityLabel()
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard
            let identifier = segue.identifier,
            let segueType = Segue(rawValue: identifier),
            let cell = sender as? UITableViewCell,
            let indexPath = self.tableView.indexPath(for: cell)
        else { return }
        
        switch segueType
        {
        case Segue.controllers:
            let controllersSettingsViewController = segue.destination as! ControllersSettingsViewController
            controllersSettingsViewController.playerIndex = indexPath.row
            
        case Segue.controllerSkins:
            let gameTypeControllerSkinsViewController = segue.destination as! GameTypeControllerSkinsViewController
            
            switch indexPath.row
            {
            case 0: gameTypeControllerSkinsViewController.gameType = .snes
            case 1: gameTypeControllerSkinsViewController.gameType = .gba
            default: break
            }            
        }
    }
}

private extension SettingsViewController
{
    func updateControllerOpacityLabel()
    {
        let percentage = String(format: "%.f", Settings.translucentControllerSkinOpacity * 100) + "%"
        self.controllerOpacityLabel.text = percentage
    }
}

private extension SettingsViewController
{
    @IBAction func unwindFromControllersSettingsViewController(_ segue: UIStoryboardSegue)
    {
        let indexPath = self.tableView.indexPathForSelectedRow
        
        self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
        
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
    }
}

private extension SettingsViewController
{
    @IBAction func changeControllerOpacity(with sender: UISlider)
    {
        let roundedValue = (sender.value / 0.05).rounded() * 0.05
        Settings.translucentControllerSkinOpacity = CGFloat(roundedValue)
        
        self.updateControllerOpacityLabel()
    }
    
    @IBAction func didFinishChangingControllerOpacity(with sender: UISlider)
    {
        sender.value = Float(Settings.translucentControllerSkinOpacity)
    }
}

private extension SettingsViewController
{
    dynamic func externalControllerDidConnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
    }
    
    dynamic func externalControllerDidDisconnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        if indexPath.section == Section.controllers.rawValue
        {
            if indexPath.row == Settings.localControllerPlayerIndex
            {
                cell.detailTextLabel?.text = UIDevice.current.name
            }
            else if let index = ExternalControllerManager.shared.connectedControllers.index(where: { $0.playerIndex == indexPath.row })
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
        let cell = tableView.cellForRow(at: indexPath)
        let section = Section(rawValue: indexPath.section)!
        
        switch section
        {
        case Section.controllers: self.performSegue(withIdentifier: Segue.controllers.rawValue, sender: cell)
        case Section.controllerSkins: self.performSegue(withIdentifier: Segue.controllerSkins.rawValue, sender: cell)
        case Section.controllerOpacity: break
        }
    }
}
