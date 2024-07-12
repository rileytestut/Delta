//
//  SettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 9/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices
import QuickLook
import MessageUI

import DeltaCore
import Harmony

import Roxas

private extension SettingsViewController
{
    enum Section: Int
    {
        case controllers
        case controllerSkins
        case controllerOpacity
        case display
        case gameAudio
        case multitasking
        case hapticFeedback
        case syncing
        case gestures
        case airPlay
        case hapticTouch
        case cores
        case advanced
        case patreon
        case credits
        case support
    }
    
    enum Segue: String
    {
        case controllers = "controllersSegue"
        case controllerSkins = "controllerSkinsSegue"
        case altAppIcons = "altAppIconsSegue"
        case dsSettings = "dsSettingsSegue"
    }

    enum AirPlayRow: Int, CaseIterable
    {
        case displayFullScreen
        case topScreenOnly
        case layoutHorizontally
    }
    
    enum SyncingRow: Int, CaseIterable
    {
        case service
        case status
    }
    
    enum AdvancedRow: Int, CaseIterable
    {
        case exportLog
        case experimentalFeatures
    }
    
    enum PatreonRow: Int, CaseIterable
    {
        case joinPatreon
        case connectAccount
    }
    
    enum CreditsRow: Int, CaseIterable
    {
        case riley
        case shane
        case caroline
        case grant
        case litRitt
        case contributors
        case softwareLicenses
    }
    
    enum SupportRow: Int, CaseIterable
    {
        case contactUs
        case privacyPolicy
    }
}

class SettingsViewController: UITableViewController
{
    @IBOutlet private var controllerOpacityLabel: UILabel!
    @IBOutlet private var controllerOpacitySlider: UISlider!
    
    @IBOutlet private var respectSilentModeSwitch: UISwitch!
    @IBOutlet private var pauseWhileInactiveSwitch: UISwitch!
    @IBOutlet private var supportExternalDisplaysSwitch: UISwitch!
    @IBOutlet private var topScreenOnlySwitch: UISwitch!
    @IBOutlet private var layoutScreensHorizontallySwitch: UISwitch!
    @IBOutlet private var buttonHapticFeedbackEnabledSwitch: UISwitch!
    @IBOutlet private var thumbstickHapticFeedbackEnabledSwitch: UISwitch!
    @IBOutlet private var previewsEnabledSwitch: UISwitch!
    @IBOutlet private var quickGesturesSwitch: UISwitch!
    
    @IBOutlet private var versionLabel: UILabel!
    
    @IBOutlet private var syncingServiceLabel: UILabel!
    @IBOutlet private var exportLogActivityIndicatorView: UIActivityIndicatorView!
    
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    
    private var previousSelectedRowIndexPath: IndexPath?
    
    private var syncingConflictsCount = 0
    
    private var _exportedLogURL: URL?
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.settingsDidChange(with:)), name: Settings.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalGameControllerDidConnect(_:)), name: .externalGameControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.externalGameControllerDidDisconnect(_:)), name: .externalGameControllerDidDisconnect, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let version = Bundle.main.object(forInfoDictionaryKey: "DLTAVersion") as? String
        {
            self.versionLabel.text = NSLocalizedString(String(format: "Delta %@", version), comment: "Delta Version")
        }
        else if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
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
        
        if #available(iOS 15, *)
        {
            self.tableView.register(AttributedHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: AttributedHeaderFooterView.reuseIdentifier)
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
            
        case Segue.dsSettings, Segue.altAppIcons: break
        }
    }
}

private extension SettingsViewController
{
    func update()
    {
        self.controllerOpacitySlider.value = Float(Settings.translucentControllerSkinOpacity)
        self.updateControllerOpacityLabel()
        
        self.respectSilentModeSwitch.isOn = Settings.respectSilentMode
        self.pauseWhileInactiveSwitch.isOn = Settings.pauseWhileInactive
        
        self.supportExternalDisplaysSwitch.isOn = Settings.supportsExternalDisplays
        self.topScreenOnlySwitch.isOn = Settings.features.dsAirPlay.topScreenOnly
        self.layoutScreensHorizontallySwitch.isOn = (Settings.features.dsAirPlay.layoutAxis == .horizontal)
        
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
        self.quickGesturesSwitch.isOn = Settings.isQuickGesturesEnabled
        
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
        case .multitasking where !UIApplication.shared.supportsMultipleScenes: return true
        case .hapticFeedback where !UIDevice.current.isVibrationSupported: return true
            
        case .advanced:
            guard #unavailable(iOS 15) else { return false }
            
            // OSLogStore is not available on iOS 14, so section is only visible if experimental features is visible.
            return !ExperimentalFeatures.isExperimentalFeaturesAvailable
            
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
    
    @IBAction func toggleRespectSilentMode(_ sender: UISwitch)
    {
        Settings.respectSilentMode = sender.isOn
    }
    
    @IBAction func togglePauseWhileInactive(_ sender: UISwitch)
    {
        Settings.pauseWhileInactive = sender.isOn
    }
    
    @IBAction func toggleSupportExternalDisplays(_ sender: UISwitch)
    {
        Settings.supportsExternalDisplays = sender.isOn
        
        self.tableView.performBatchUpdates({
            let topScreenOnlyIndexPath = IndexPath(row: AirPlayRow.topScreenOnly.rawValue, section: Section.airPlay.rawValue)
            let layoutHorizontallyIndexPath = IndexPath(row: AirPlayRow.layoutHorizontally.rawValue, section: Section.airPlay.rawValue)
            if sender.isOn
            {
                self.tableView.insertRows(at: [topScreenOnlyIndexPath], with: .top)
                
                if !Settings.features.dsAirPlay.topScreenOnly
                {
                    self.tableView.insertRows(at: [layoutHorizontallyIndexPath], with: .top)
                }
            }
            else
            {
                self.tableView.deleteRows(at: [topScreenOnlyIndexPath], with: .top)
                
                if !Settings.features.dsAirPlay.topScreenOnly
                {
                    self.tableView.deleteRows(at: [layoutHorizontallyIndexPath], with: .top)
                }
            }
            
        }) { _ in
            self.tableView.reloadSections([Section.airPlay.rawValue], with: .none)
        }
    }
    
    @IBAction func toggleTopScreenOnly(_ sender: UISwitch)
    {
        Settings.features.dsAirPlay.topScreenOnly = sender.isOn
        
        self.tableView.performBatchUpdates({
            let layoutHorizontallyIndexPath = IndexPath(row: AirPlayRow.layoutHorizontally.rawValue, section: Section.airPlay.rawValue)
            if sender.isOn
            {
                self.tableView.deleteRows(at: [layoutHorizontallyIndexPath], with: .top)
            }
            else
            {
                self.tableView.insertRows(at: [layoutHorizontallyIndexPath], with: .top)
            }
        }) { _ in
            self.tableView.reloadSections([Section.airPlay.rawValue], with: .none)
        }
    }
    
    @IBAction func toggleLayoutHorizontally(_ sender: UISwitch)
    {
        Settings.features.dsAirPlay.layoutAxis = sender.isOn ? .horizontal : .vertical
        
        self.tableView.reloadSections([Section.airPlay.rawValue], with: .none)
    }
    
    @IBAction func toggleQuickGesturesEnabled(_ sender: UISwitch)
    {
        Settings.isQuickGesturesEnabled = sender.isOn
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
    
    func openThreads(username: String)
    {
        // Rely on universal links to open app.
        
        let safariURL = URL(string: "https://www.threads.net/@" + username)!
        UIApplication.shared.open(safariURL, options: [:])
    }
    
    @available(iOS 14, *)
    func showContributors()
    {
        let hostingController = ContributorsView.makeViewController()
        self.navigationController?.pushViewController(hostingController, animated: true)
    }
    
    func showExperimentalFeatures()
    {
        let hostingController = ExperimentalFeaturesView.makeViewController()
        self.navigationController?.pushViewController(hostingController, animated: true)
    }
    
    @available(iOS 15, *)
    func exportErrorLog()
    {
        self.exportLogActivityIndicatorView.startAnimating()
        
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        Task<Void, Never>.detached(priority: .userInitiated) {
            do
            {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                
                // All logs since the app launched.
                let position = store.position(timeIntervalSinceLatestBoot: 0)
                let predicate = NSPredicate(format: "subsystem IN %@", [Logger.deltaSubsystem, Logger.harmonySubsystem])
                
                let entries = try store.getEntries(at: position, matching: predicate)
                    .compactMap { $0 as? OSLogEntryLog }
                    .map { "[\($0.date.formatted())] [\($0.category)] [\($0.level.localizedName)] \($0.composedMessage)" }
                
                let outputText = entries.joined(separator: "\n")
                                
                let outputDirectory = FileManager.default.uniqueTemporaryURL()
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                
                let outputURL = outputDirectory.appendingPathComponent("delta.log")
                try outputText.write(to: outputURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    self._exportedLogURL = outputURL
                    
                    let previewController = QLPreviewController()
                    previewController.delegate = self
                    previewController.dataSource = self
                    self.present(previewController, animated: true)
                }
            }
            catch
            {
                print("Failed to export Harmony logs.", error)
            }
                        
            await self.exportLogActivityIndicatorView.stopAnimating()
        }
    }
    
    func joinPatreonCampaign()
    {
        let patreonDeepLink = URL(string: "altstore://patreon")!
        let patreonURL = URL(string: "https://www.patreon.com/rileyshane")!
        
        let patreonAccount = DatabaseManager.shared.patreonAccount()
        
        // Prefer opening Patreon page in AltStore if it's installed.
        // But only if we're not already a patron, otherwise open webpage directly.
        if UIApplication.shared.canOpenURL(patreonDeepLink), patreonAccount?.isPatron != true
        {
            UIApplication.shared.open(patreonDeepLink, options: [:]) { (success) in
                guard !success else { return }
                
                UIApplication.shared.open(patreonURL)
            }
        }
        else
        {
            UIApplication.shared.open(patreonURL)
        }
    }
    
    func authenticatePatreonAccount()
    {
        PatreonAPI.shared.authenticate(presentingViewController: self) { (result) in
            do
            {
                let account = try result.get()
                try account.managedObjectContext?.save()
                
                DispatchQueue.main.async {
                    self.update()
                }
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Authenticate with Patreon", comment: ""), error: error)
                    self.present(alertController, animated: true)
                }
            }
        }
    }
    
    func signOutPatreonAccount()
    {
        func signOut()
        {
            PatreonAPI.shared.signOut { (result) in
                do
                {
                    try result.get()
                    
                    DispatchQueue.main.async {
                        self.update()
                    }
                }
                catch
                {
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: NSLocalizedString("Unable to Sign Out of Patreon", comment: ""), error: error)
                        self.present(alertController, animated: true)
                    }
                }
            }
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to unlink your Patreon account?", comment: ""),
                                                message: NSLocalizedString("You will no longer be able to access Patreon-exclusive features.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Unlink Patreon Account", comment: ""), style: .destructive) { _ in signOut() })
        alertController.addAction(.cancel)
        
        let indexPath = IndexPath(item: PatreonRow.connectAccount.rawValue, section: Section.patreon.rawValue)
        let frame = self.tableView.rectForRow(at: indexPath)
        alertController.popoverPresentationController?.sourceRect = frame
        alertController.popoverPresentationController?.sourceView = self.tableView
        
        self.present(alertController, animated: true, completion: nil)
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
            
        case .localControllerPlayerIndex, .preferredControllerSkin, .translucentControllerSkinOpacity, .respectSilentMode, .isButtonHapticFeedbackEnabled, .isThumbstickHapticFeedbackEnabled, .isAltJITEnabled: break
        default: break
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
        case .controllers: return 4
        case .controllerSkins: return System.registeredSystems.count
        case .airPlay:
            var numberOfRows = 1
            
            if Settings.supportsExternalDisplays
            {
                // Show additional options if primary setting is enabled.
                numberOfRows += 1
                
                if Settings.features.dsAirPlay.topScreenOnly
                {
                    // Layout axis is irrelevant if only AirPlaying top screen.
                }
                else
                {
                    numberOfRows += 1
                }
            }
            
            return numberOfRows
            
        #if APP_STORE || LEGACY
        case .patreon: 
            // Hide "Connect Account" option from APP_STORE and LEGACY builds.
            return 1
        #endif
            
        case .syncing where !isSectionHidden(section): return SyncManager.shared.coordinator?.account == nil ? 1 : super.tableView(tableView, numberOfRowsInSection: sectionIndex)
        case .advanced where !isSectionHidden(section):
            if ExperimentalFeatures.isExperimentalFeaturesAvailable
            {
                return super.tableView(tableView, numberOfRowsInSection: sectionIndex)
            }
            else
            {
                return 1
            }
            
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
                cell.detailTextLabel?.text = LocalDeviceController().name
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
            
        case .patreon:
            let row = PatreonRow(rawValue: indexPath.row)!
            switch row
            {
            case .joinPatreon:
                if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.isPatron
                {
                    cell.textLabel?.text = NSLocalizedString("View Patreon", comment: "")
                }
                else
                {
                    cell.textLabel?.text = NSLocalizedString("Join our Patreon", comment: "")
                }
                
            case .connectAccount:
                var content = cell.defaultContentConfiguration()
                content.textProperties.color = .deltaPurple
                
                if let patreonAccount = DatabaseManager.shared.patreonAccount()
                {
                    let text = String(format: NSLocalizedString("Unlink %@", comment: ""), patreonAccount.name)
                    content.text = text
                }
                else
                {
                    content.text = NSLocalizedString("Connect Account…", comment: "")
                }
                
                cell.contentConfiguration = content
            }
            
        case .controllerOpacity, .display, .gameAudio, .multitasking, .hapticFeedback, .gestures, .airPlay, .hapticTouch, .advanced, .credits, .support: break
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
        case .display: self.performSegue(withIdentifier: Segue.altAppIcons.rawValue, sender: cell)
        case .cores: self.performSegue(withIdentifier: Segue.dsSettings.rawValue, sender: cell)
        case .controllerOpacity, .gameAudio, .multitasking, .hapticFeedback, .gestures, .airPlay, .hapticTouch, .syncing: break
        case .advanced:
            let row = AdvancedRow(rawValue: indexPath.row)!
            switch row
            {
            case .exportLog:
                guard #available(iOS 15, *) else { return }
                self.exportErrorLog()
                
            case .experimentalFeatures: self.showExperimentalFeatures()
            }

        case .patreon:
            let row = PatreonRow(rawValue: indexPath.row)!
            switch row
            {
            case .joinPatreon: self.joinPatreonCampaign()
            case .connectAccount:
                if let _ = DatabaseManager.shared.patreonAccount()
                {
                    self.signOutPatreonAccount()
                }
                else
                {
                    self.authenticatePatreonAccount()
                }
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
            
        case .credits:
            let row = CreditsRow(rawValue: indexPath.row)!
            switch row
            {
            case .riley: self.openThreads(username: "rileytestut")
            case .shane: self.openThreads(username: "shanegill.io")
            case .caroline: self.openThreads(username: "carolinemoore")
            case .grant: self.openThreads(username: "glinstagrant")
            case .litRitt: self.openTwitter(username: "lit_ritt")
            case .contributors:
                guard #available(iOS 14, *) else { return }
                self.showContributors()
                
            case .softwareLicenses: break
            }
            
        case .support:
            let row = SupportRow.allCases[indexPath.row]
            switch row
            {
            case .contactUs:
                if MFMailComposeViewController.canSendMail()
                {
                    let mailViewController = MFMailComposeViewController()
                    mailViewController.mailComposeDelegate = self
                    mailViewController.setToRecipients(["support@altstore.io"])
                    
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    {
                        mailViewController.setSubject("Delta \(version) Feedback")
                    }
                    else
                    {
                        mailViewController.setSubject("Delta Feedback")
                    }
                    
                    self.present(mailViewController, animated: true, completion: nil)
                }
                else
                {
                    let toastView = RSTToastView(text: NSLocalizedString("Cannot Send Mail", comment: ""), detailText: nil)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 4.0)
                }
                
            case .privacyPolicy:
                let safariURL = URL(string: "https://altstore.io/privacy")!
                UIApplication.shared.open(safariURL, options: [:])
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
    primary:
        switch Section(rawValue: indexPath.section)!
        {
        case .airPlay:
            let row = AirPlayRow(rawValue: indexPath.row)!
            switch row
            {
            case .topScreenOnly, .layoutHorizontally: return UITableView.automaticDimension
            case .displayFullScreen: break primary
            }
            
        case .advanced:
            let row = AdvancedRow(rawValue: indexPath.row)!
            switch row
            {
            case .exportLog:
                guard #unavailable(iOS 15) else { break }
                return 0.0
                
            default: break
            }
            
        case .credits:
            let row = CreditsRow(rawValue: indexPath.row)!
            switch row
            {
            case .grant:
                // Hide row on iOS 14 and above
                guard #available(iOS 14, *) else { break primary }
                return 0.0
                
            case .litRitt:
                // Hide row on iOS 14 and above
                guard #available(iOS 14, *) else { break primary }
                return 0.0
                
            case .contributors:
                // Hide row on iOS 13 and below
                guard #unavailable(iOS 14) else { break primary }
                return 0.0
                
            default: break
            }
            
        default: break
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return nil }
        
        switch section
        {
        case .airPlay where self.view.traitCollection.userInterfaceIdiom == .pad: return NSLocalizedString("AirPlay / External Displays", comment: "")
        case .hapticTouch where self.view.traitCollection.forceTouchCapability == .available: return NSLocalizedString("3D Touch", comment: "")
        default: return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? 
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return nil }
        
        switch section
        {
        case .controllerSkins:
            guard #available(iOS 15, *), let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: AttributedHeaderFooterView.reuseIdentifier) as? AttributedHeaderFooterView else { break }
            
            var attributedText = AttributedString(localized: "Customize the appearance of each system.")
            attributedText += " "
            
            var learnMore = AttributedString(localized: "Learn more…")
            learnMore.link = URL(string: "https://faq.deltaemulator.com/using-delta/controller-skins")
            attributedText += learnMore
            
            footerView.attributedText = attributedText
                        
            return footerView
            
        default: break
        }
        
        return super.tableView(tableView, viewForFooterInSection: section.rawValue)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return nil }
        
        switch section
        {
        case .advanced:
            if ExperimentalFeatures.isExperimentalFeaturesAvailable
            {
                return super.tableView(tableView, titleForFooterInSection: section.rawValue)
            }
            else
            {
                return nil
            }
            
        case .controllerSkins: return nil
        case .airPlay:
            switch (Settings.supportsExternalDisplays, Settings.features.dsAirPlay.topScreenOnly, Settings.features.dsAirPlay.layoutAxis)
            {
            case (false, _, _): return NSLocalizedString("Games will not take over the entire display when AirPlaying.", comment: "")
            case (true, true, _): return NSLocalizedString("When AirPlaying DS games, only the top screen will appear on the external display.", comment: "")
            case (true, false, .vertical): return NSLocalizedString("When AirPlaying DS games, both screens will be stacked vertically on the external display.", comment: "")
            case (true, false, .horizontal): return NSLocalizedString("When AirPlaying DS games, both screens will be placed side-by-side on the external display.", comment: "")
            }
            
        default: return super.tableView(tableView, titleForFooterInSection: section.rawValue)
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
        guard !isSectionHidden(section) else { return 1 }
        
        switch section
        {
        case .controllerSkins: return UITableView.automaticDimension
        default: return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat 
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return 1 }
        
        switch section
        {
        case .controllerSkins: return 30
        default: return UITableView.automaticDimension
        }
    }
}

extension SettingsViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate
{
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int 
    {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem 
    {
        return (_exportedLogURL as? NSURL) ?? NSURL()
    }
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) 
    {
        guard let exportedLogURL = _exportedLogURL else { return }
        
        let parentDirectory = exportedLogURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parentDirectory)
        
        _exportedLogURL = nil
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        if let error = error
        {
            let toastView = RSTToastView(error: error)
            toastView.show(in: self.navigationController?.view ?? self.view, duration: 4.0)
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}
