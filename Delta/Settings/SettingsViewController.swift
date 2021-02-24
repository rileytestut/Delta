//
//  SettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices

import DeltaCore

import Roxas

private extension SettingsViewController
{
    enum Section: Int
    {
        case controllers
        case controllerSkins
        case controllerOpacity
        case hapticFeedback
        case syncing
        case hapticTouch
        case cores
        case patreon
        case credits
    }
    
    enum Segue: String
    {
        case controllers = "controllersSegue"
        case controllerSkins = "controllerSkinsSegue"
        case dsSettings = "dsSettingsSegue"
    }

    enum SyncingRow: Int, CaseIterable
    {
        case service
        case status
    }
    
    enum CreditsRow: Int, CaseIterable
    {
        case riley
        case caroline
        case grant
        case litRitt
        case softwareLicenses
    }
}

class SettingsViewController: UITableViewController
{
    @IBOutlet private var controllerOpacityLabel: UILabel!
    @IBOutlet private var controllerOpacitySlider: UISlider!
    
    @IBOutlet private var buttonHapticFeedbackEnabledSwitch: UISwitch!
    @IBOutlet private var thumbstickHapticFeedbackEnabledSwitch: UISwitch!
    @IBOutlet private var previewsEnabledSwitch: UISwitch!
    
    @IBOutlet private var versionLabel: UILabel!
    
    @IBOutlet private var syncingServiceLabel: UILabel!
    
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    
    private var previousSelectedRowIndexPath: IndexPath?
    
    private var syncingConflictsCount = 0
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.settingsDidChange(with:)), name: .settingsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalGameControllerDidConnect(_:)), name: .externalGameControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalGameControllerDidDisconnect(_:)), name: .externalGameControllerDidDisconnect, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        {
            #if LITE
            self.versionLabel.text = NSLocalizedString(String(format: "Delta Lite %@", version), comment: "Delta Version")
            #else
            self.versionLabel.text = NSLocalizedString(String(format: "Delta %@", version), comment: "Delta Version")
            #endif
        }
        else
        {
            #if LITE
            self.versionLabel.text = NSLocalizedString("Delta Lite", comment: "")
            #else
            self.versionLabel.text = NSLocalizedString("Delta", comment: "")
            #endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if let indexPath = self.previousSelectedRowIndexPath
        {
            if indexPath.section == Section.controllers.rawValue
            {
                // Update and temporarily re-select selected row.
                self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
                self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: UITableView.ScrollPosition.none)
            }
            
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        self.update()
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
        
        self.previousSelectedRowIndexPath = indexPath
        
        switch segueType
        {
        case Segue.controllers:
            let controllersSettingsViewController = segue.destination as! ControllersSettingsViewController
            controllersSettingsViewController.playerIndex = indexPath.row
            
        case Segue.controllerSkins:
            let preferredControllerSkinsViewController = segue.destination as! PreferredControllerSkinsViewController
            
            let system = System.registeredSystems[indexPath.row]
            preferredControllerSkinsViewController.system = system
            
        case Segue.dsSettings: break
        }
    }
}

private extension SettingsViewController
{
    func update()
    {
        self.controllerOpacitySlider.value = Float(Settings.translucentControllerSkinOpacity)
        self.updateControllerOpacityLabel()
        
        self.syncingServiceLabel.text = Settings.syncingService?.localizedName
        
        do
        {
            let records = try SyncManager.shared.recordController?.fetchConflictedRecords() ?? []
            self.syncingConflictsCount = records.count
        }
        catch
        {
            print(error)
        }
        
        self.buttonHapticFeedbackEnabledSwitch.isOn = Settings.isButtonHapticFeedbackEnabled
        self.thumbstickHapticFeedbackEnabledSwitch.isOn = Settings.isThumbstickHapticFeedbackEnabled
        self.previewsEnabledSwitch.isOn = Settings.isPreviewsEnabled
        
        self.tableView.reloadData()
    }
    
    func updateControllerOpacityLabel()
    {
        let percentage = String(format: "%.f", Settings.translucentControllerSkinOpacity * 100) + "%"
        self.controllerOpacityLabel.text = percentage
    }
    
    func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
        case .hapticTouch:
            if #available(iOS 13, *)
            {
                // All devices on iOS 13 support either 3D touch or Haptic Touch.
                return false
            }
            else
            {
                return self.view.traitCollection.forceTouchCapability != .available
            }
            
        default: return false
        }
    }
}

private extension SettingsViewController
{
    @IBAction func beginChangingControllerOpacity(with sender: UISlider)
    {
        self.selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        self.selectionFeedbackGenerator?.prepare()
    }
    
    @IBAction func changeControllerOpacity(with sender: UISlider)
    {
        let roundedValue = CGFloat((sender.value / 0.05).rounded() * 0.05)
        
        if roundedValue != Settings.translucentControllerSkinOpacity
        {
            self.selectionFeedbackGenerator?.selectionChanged()
        }
        
        Settings.translucentControllerSkinOpacity = CGFloat(roundedValue)
        
        self.updateControllerOpacityLabel()
    }
    
    @IBAction func didFinishChangingControllerOpacity(with sender: UISlider)
    {
        sender.value = Float(Settings.translucentControllerSkinOpacity)
        self.selectionFeedbackGenerator = nil
    }
    
    @IBAction func toggleButtonHapticFeedbackEnabled(_ sender: UISwitch)
    {
        Settings.isButtonHapticFeedbackEnabled = sender.isOn
    }
    
    @IBAction func toggleThumbstickHapticFeedbackEnabled(_ sender: UISwitch)
    {
        Settings.isThumbstickHapticFeedbackEnabled = sender.isOn
    }
    
    @IBAction func togglePreviewsEnabled(_ sender: UISwitch)
    {
        Settings.isPreviewsEnabled = sender.isOn
    }
    
    func openTwitter(username: String)
    {
        let twitterAppURL = URL(string: "twitter://user?screen_name=" + username)!
        UIApplication.shared.open(twitterAppURL, options: [:]) { (success) in
            if success
            {
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow
                {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            }
            else
            {
                let safariURL = URL(string: "https://twitter.com/" + username)!
                
                let safariViewController = SFSafariViewController(url: safariURL)
                safariViewController.preferredControlTintColor = .deltaPurple
                self.present(safariViewController, animated: true, completion: nil)
            }
        }
    }
}

private extension SettingsViewController
{
    @objc func settingsDidChange(with notification: Notification)
    {
        guard let settingsName = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name else { return }
        
        switch settingsName
        {
        case .syncingService:
            let selectedIndexPath = self.tableView.indexPathForSelectedRow
            
            self.tableView.reloadSections(IndexSet(integer: Section.syncing.rawValue), with: .none)
            
            let syncingServiceIndexPath = IndexPath(row: SyncingRow.service.rawValue, section: Section.syncing.rawValue)
            if selectedIndexPath == syncingServiceIndexPath
            {
                self.tableView.selectRow(at: selectedIndexPath, animated: true, scrollPosition: .none)
            }
            
        case .localControllerPlayerIndex, .preferredControllerSkin, .translucentControllerSkinOpacity, .isButtonHapticFeedbackEnabled, .isThumbstickHapticFeedbackEnabled: break
        }
    }

    @objc func externalGameControllerDidConnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
    }
    
    @objc func externalGameControllerDidDisconnect(_ notification: Notification)
    {
        self.tableView.reloadSections(IndexSet(integer: Section.controllers.rawValue), with: .none)
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int
    {
        let section = Section(rawValue: sectionIndex)!
        switch section
        {
        case .controllers: return 1 // Temporarily hide other controller indexes until controller logic is finalized
        case .controllerSkins: return System.registeredSystems.count
        case .syncing: return SyncManager.shared.coordinator?.account == nil ? 1 : super.tableView(tableView, numberOfRowsInSection: sectionIndex)
        default:
            if isSectionHidden(section)
            {
                return 0
            }
            else
            {
                return super.tableView(tableView, numberOfRowsInSection: sectionIndex)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        let section = Section(rawValue: indexPath.section)!
        switch section
        {
        case .controllers:
            if indexPath.row == Settings.localControllerPlayerIndex
            {
                cell.detailTextLabel?.text = UIDevice.current.name
            }
            else if let index = ExternalGameControllerManager.shared.connectedControllers.firstIndex(where: { $0.playerIndex == indexPath.row })
            {
                let controller = ExternalGameControllerManager.shared.connectedControllers[index]
                cell.detailTextLabel?.text = controller.name
            }
            else
            {
                cell.detailTextLabel?.text = nil
            }
            
        case .controllerSkins:
            cell.textLabel?.text = System.registeredSystems[indexPath.row].localizedName
                        
        case .syncing:
            switch SyncingRow.allCases[indexPath.row]
            {
            case .status:
                let cell = cell as! BadgedTableViewCell
                cell.badgeLabel.text = self.syncingConflictsCount.description
                cell.badgeLabel.isHidden = (self.syncingConflictsCount == 0)
                
            case .service: break
            }
            
        case .cores:
            let preferredCore = Settings.preferredCore(for: .ds)
            cell.detailTextLabel?.text = preferredCore?.metadata?.name.value ?? preferredCore?.name ?? NSLocalizedString("Unknown", comment: "")
            
        case .controllerOpacity, .hapticFeedback, .hapticTouch, .patreon, .credits: break
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let cell = tableView.cellForRow(at: indexPath)
        let section = Section(rawValue: indexPath.section)!

        switch section
        {
        case .controllers: self.performSegue(withIdentifier: Segue.controllers.rawValue, sender: cell)
        case .controllerSkins: self.performSegue(withIdentifier: Segue.controllerSkins.rawValue, sender: cell)
        case .cores: self.performSegue(withIdentifier: Segue.dsSettings.rawValue, sender: cell)
        case .controllerOpacity, .hapticFeedback, .hapticTouch, .syncing: break
        case .patreon:
            let patreonURL = URL(string: "altstore://patreon")!
            
            UIApplication.shared.open(patreonURL, options: [:]) { (success) in
                guard !success else { return }
                
                let patreonURL = URL(string: "https://www.patreon.com/rileytestut")!
                
                let safariViewController = SFSafariViewController(url: patreonURL)
                safariViewController.preferredControlTintColor = .deltaPurple
                self.present(safariViewController, animated: true, completion: nil)
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
            
        case .credits:
            let row = CreditsRow(rawValue: indexPath.row)!
            switch row
            {
            case .riley: self.openTwitter(username: "rileytestut")
            case .caroline: self.openTwitter(username: "1carolinemoore")
            case .grant: self.openTwitter(username: "grantgliner")
            case .litRitt: self.openTwitter(username: "litritt_z")
            case .softwareLicenses: break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return nil }
        
        switch section
        {
        case .hapticTouch where self.view.traitCollection.forceTouchCapability == .available: return NSLocalizedString("3D Touch", comment: "")
        default: return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        let section = Section(rawValue: section)!
        
        if isSectionHidden(section)
        {
            return nil
        }
        else
        {
            return super.tableView(tableView, titleForFooterInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section(rawValue: section)!
        
        if isSectionHidden(section)
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
        let section = Section(rawValue: section)!
        
        if isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
}
