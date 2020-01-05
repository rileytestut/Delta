//
//  SettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

#if os(iOS)
import SafariServices
#endif

import DeltaCore

import Roxas

#if os(tvOS)
import TvOSTextViewer
#endif

private extension SettingsViewController
{
    enum Section: Int
    {
        #if os(tvOS)
        case controllers
        case syncing
        case credits
        #else
        case controllers
        case controllerSkins
        case controllerOpacity
        case hapticFeedback
        case syncing
        case threeDTouch
        case patreon
        case credits
        #endif
    }
    
    enum Segue: String
    {
        case controllers = "controllersSegue"
        case controllerSkins = "controllerSkinsSegue"
        #if os(tvOS)
        case tvLicenses = "tvLicensesSegue"
        #endif
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
        case softwareLicenses
    }
}

class SettingsViewController: UITableViewController
{
    #if os(iOS)
    @IBOutlet private var controllerOpacityLabel: UILabel!
    @IBOutlet private var controllerOpacitySlider: UISlider!
    
    @IBOutlet private var buttonHapticFeedbackEnabledSwitch: UISwitch!
    @IBOutlet private var thumbstickHapticFeedbackEnabledSwitch: UISwitch!
    #endif
    
    @IBOutlet private var versionLabel: UILabel!
    
    @IBOutlet private var syncingServiceLabel: UILabel!

    #if os(iOS)
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    #endif
    
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
            #if os(tvOS)
            let controllersSettingsViewController = (segue.destination as! UINavigationController).topViewController as! ControllersSettingsViewController
            #else
            let controllersSettingsViewController = segue.destination as! ControllersSettingsViewController
            #endif
            controllersSettingsViewController.playerIndex = indexPath.row
            
        case Segue.controllerSkins:
            let systemControllerSkinsViewController = segue.destination as! SystemControllerSkinsViewController
            
            let system = System.registeredSystems[indexPath.row]
            systemControllerSkinsViewController.system = system
        #if os(tvOS)
        case .tvLicenses:
            // this is an annoying duplication of the license text, but at least places the text in
            // a scrollable field so you can read it on tvOS
            let tvLicensesViewController = (segue.destination as! UINavigationController).topViewController as! TvOSTextViewerViewController
            tvLicensesViewController.textEdgeInsets = UIEdgeInsets(top: 100, left: 300, bottom: 100, right: 300)
            tvLicensesViewController.textAttributes = [.foregroundColor: UIColor.gray, .font: UIFont.systemFont(ofSize: 24.0)]
            tvLicensesViewController.text = """
            Delta and AltStore LLC are in no way affiliated with Nintendo Co., Ltd.

            Stephen Celis (SQLite.swift)
            Copyright (c) 2014-2015 Stephen Celis (<stephen@stephencelis.com>)
            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:
            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.
            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.

            Olivier Poitrey (SDWebImage)
            Copyright (c) 2009-2018 Olivier Poitrey rs@dailymotion.com
            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is furnished
            to do so, subject to the following conditions:
            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.
            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
            THE SOFTWARE.

            Thomas Zoechling (ZIPFoundation)
            Copyright (c) 2017 Thomas Zoechling
            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:
            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.
            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.

            Dropbox Inc. (SwiftyDropbox)
            Copyright (c) 2015 Dropbox Inc., http://www.dropbox.com/
            Permission is hereby granted, free of charge, to any person obtaining
            a copy of this software and associated documentation files (the
            "Software"), to deal in the Software without restriction, including
            without limitation the rights to use, copy, modify, merge, publish,
            distribute, sublicense, and/or sell copies of the Software, and to
            permit persons to whom the Software is furnished to do so, subject to
            the following conditions:
            The above copyright notice and this permission notice shall be
            included in all copies or substantial portions of the Software.
            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
            EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
            MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
            NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
            LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
            OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
            WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

            Google (Google API Objective-C Client)
            Licensed under Apache 2 license.

            Nick Farina (SMCalloutView)
            Licensed under Apache 2 license.

            Delta uses these emulator cores licensed under the GNU Public License version 2:

            Nestopia
            Snes9x
            mupen64plus
            Gambatte
            visualboyadvance-m
            DeSmuME

            Delta uses OpenVGDB to provide automatic artwork for imported games.
            """
        #endif
            
        }
    }
}

private extension SettingsViewController
{
    func update()
    {
        #if os(iOS)
        self.controllerOpacitySlider.value = Float(Settings.translucentControllerSkinOpacity)
        self.updateControllerOpacityLabel()
        #endif
        
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

        #if os(iOS)
        self.buttonHapticFeedbackEnabledSwitch.isOn = Settings.isButtonHapticFeedbackEnabled
        self.thumbstickHapticFeedbackEnabledSwitch.isOn = Settings.isThumbstickHapticFeedbackEnabled
        #endif
        
        self.tableView.reloadData()
    }
    
    #if os(iOS)
    func updateControllerOpacityLabel()
    {
        let percentage = String(format: "%.f", Settings.translucentControllerSkinOpacity * 100) + "%"
        self.controllerOpacityLabel.text = percentage
    }
    #endif
    
    func isSectionHidden(_ section: Section) -> Bool
    {
        switch section
        {
            #if os(iOS)
        case .threeDTouch: return self.view.traitCollection.forceTouchCapability != .available
            #endif
        default: return false
        }
    }
}

private extension SettingsViewController
{
    #if os(iOS)
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
    #endif
    
    func openTwitter(username: String)
    {
        #if os(iOS)
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
        #endif
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
            #if os(iOS)
        case .controllerSkins: return System.registeredSystems.count
            #endif
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
            
            #if os(iOS)
        case .controllerSkins:
            cell.textLabel?.text = System.registeredSystems[indexPath.row].localizedName
            #endif
                        
        case .syncing:
            switch SyncingRow.allCases[indexPath.row]
            {
            case .status:
                let cell = cell as! BadgedTableViewCell
                cell.badgeLabel.text = self.syncingConflictsCount.description
                cell.badgeLabel.isHidden = (self.syncingConflictsCount == 0)
                
            case .service: break
            }

            #if os(iOS)
        case .controllerOpacity, .hapticFeedback, .threeDTouch, .patreon, .credits: break
            #else
        case .credits: break
            #endif
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
        #if os(iOS)
        case .controllerSkins: self.performSegue(withIdentifier: Segue.controllerSkins.rawValue, sender: cell)
        case .controllerOpacity, .hapticFeedback, .threeDTouch, .syncing: break
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
        #else
        case .syncing: break
        #endif
            
        case .credits:
            let row = CreditsRow(rawValue: indexPath.row)!
            switch row
            {
            case .riley: self.openTwitter(username: "rileytestut")
            case .caroline: self.openTwitter(username: "1carolinemoore")
            case .grant: self.openTwitter(username: "grantgliner")
            case .softwareLicenses: break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section(rawValue: section)!
        
        if isSectionHidden(section)
        {
            return nil
        }
        else
        {
            return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
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
