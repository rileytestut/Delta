//
//  SyncingServicesViewController.swift
//  Delta
//
//  Created by Riley Testut on 6/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Harmony
#if !os(tvOS)
// currently unable to get Harmony_Drive to compile for tvOS (due to Google dependencies
// compiled for iOS only), so only Dropbox is supported for now for tvOS
import Harmony_Drive
#endif

import Roxas

// Voucher wraps the Bonjour protocol and enabled us to communicate from iOS-tvOS
// as such voucher is needed by both iOS and tvOS
import Voucher

extension SyncingServicesViewController
{
    enum Section: Int, CaseIterable
    {
        case syncing
        case service
        case account
        case voucher
        case authenticate
    }
    
    enum AccountRow: Int, CaseIterable
    {
        case name
        case emailAddress
    }
}

class SyncingServicesViewController: UITableViewController
{
    #if os(iOS)
    @IBOutlet private var syncingEnabledSwitch: UISwitch!
    #elseif os(tvOS)
    var isSyncingEnabled: Bool = false
    #endif
    
    private var selectedSyncingService = Settings.syncingService
    
    #if os(iOS)
    private var voucherServer: VoucherServer?
    #elseif os(tvOS)
    private var voucherClient: VoucherClient?
    #endif
    enum VoucherState: Int, CaseIterable
    {
        case offline
        case online
        case waitingForConnection
        case connected
    }
    var voucherState: VoucherState = VoucherState.offline
    var connectedClientName: String? = nil
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        #if os(iOS)
        self.syncingEnabledSwitch.onTintColor = .deltaPurple
        self.syncingEnabledSwitch.isOn = (self.selectedSyncingService != nil)
        #elseif os(tvOS)
        self.isSyncingEnabled = (self.selectedSyncingService != nil)
        #endif
    }
}

private extension SyncingServicesViewController
{
    #if os(iOS)
    @IBAction func toggleSyncing(_ sender: UISwitch)
    {
        if sender.isOn
        {
            self.changeService(to: SyncManager.Service.allCases.first)
        }
        else
        {
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("Disable Syncing?", comment: ""), message: NSLocalizedString("Enabling syncing again later may result in conflicts that must be resolved manually.", comment: ""), preferredStyle: .alert)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Disable", comment: ""), style: .default) { (action) in
                    self.changeService(to: nil)
                })
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                self.changeService(to: nil)
            }
        }
    }
    #elseif os(tvOS)
    func toggleSyncing() {
        self.isSyncingEnabled.toggle()
        
        if self.isSyncingEnabled
        {
            self.changeService(to: SyncManager.Service.allCases.first)
        }
        else
        {
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("Disable Syncing?", comment: ""), message: NSLocalizedString("Enabling syncing again later may result in conflicts that must be resolved manually.", comment: ""), preferredStyle: .alert)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Disable", comment: ""), style: .default) { (action) in
                    self.changeService(to: nil)
                })
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                self.changeService(to: nil)
            }
        }
    }
    #endif
    
    func toggleVoucher() {
        let voucherUniqueSharedId = "com.rileytestut.delta.VoucherID"
        
        #if os(tvOS)

        if voucherState != VoucherState.offline {
            self.voucherClient?.stop()
            self.tableView.reloadData()
        } else {
            self.voucherClient = VoucherClient(uniqueSharedId: voucherUniqueSharedId)
            self.voucherClient?.delegate = self
            
            self.voucherClient?.startSearching { [unowned self] (authData, displayName, error) -> Void in

                defer {
                    self.voucherClient?.stop()
                }

                // handle error states
                guard let authData = authData, let responderName = displayName else {
                    if let error = error {
                        print("Encountered error retrieving data: \(error)")
                    }
                    
                    let alertController = UIAlertController(title: NSLocalizedString("Authentication Failed", comment: ""), message: NSLocalizedString("The iOS App denied our authentication request", comment: ""), preferredStyle: .alert)
                    alertController.addAction(.ok)
                    self.present(alertController, animated: true, completion: nil)
                    
                    return
                }
                
                // success!
                let tokenString = String(data: authData, encoding: String.Encoding.utf8)!
                
                let alert = UIAlertController(title: NSLocalizedString("Received Access Token!", comment: ""), message: NSLocalizedString("Successfully received auth data from '\(responderName)'. Do you still wish to use it to log into \(self.selectedSyncingService?.localizedName ?? "the service")?", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Accept", style: .default, handler: { [unowned self] action in
                    
                    SyncManager.shared.authenticate(presentingViewController: nil, accessTokenString: tokenString) { (result) in
                        DispatchQueue.main.async {
                            do
                            {
                                _ = try result.get()
                                self.tableView.reloadData()
                                
                                Settings.syncingService = self.selectedSyncingService
                            }
                            catch
                            {
                                let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), error: error)
                                alertController.addAction(.ok)
                                self.present(alertController, animated: true, completion: nil)
                            }
                        }
                    }
                }))
                alert.addAction(.cancel)
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        #elseif os(iOS)
        
        if voucherState != VoucherState.offline {
            self.voucherServer?.stop()
            self.tableView.reloadSections(IndexSet(integer: Section.voucher.rawValue), with: .none)
        } else {
            guard
                let syncingService = self.selectedSyncingService,
                let token = syncingService.service.getAccessToken()
                else {
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Start Voucher", comment: ""), message: NSLocalizedString("Unable to Start Voucher", comment: "Please ensure that you are properly authenticated and try again."), preferredStyle: .alert)
                    alertController.addAction(.ok)
                    self.present(alertController, animated: true, completion: nil)
                    return
            }
            
            self.voucherServer = VoucherServer(uniqueSharedId: voucherUniqueSharedId)
            self.voucherServer?.delegate = self

            self.voucherServer?.startAdvertising { (displayName, responseHandler) -> Void in

                let alertController = UIAlertController(title: "Connected", message: "Do you wish to continue and allow \"\(displayName)\" access to your \(syncingService.localizedName) access token?", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Not Now", style: .cancel, handler: { action in
                    responseHandler(nil, nil)
                }))
                alertController.addAction(UIAlertAction(title: "Allow", style: .default, handler: { action in
                    // Encode the token string into data to be later retrieved and converted back into a string
                    let authData = token.data(using: String.Encoding.utf8)!
                    responseHandler(authData, nil)
                }))
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        #endif
    }
    
    func changeService(to service: SyncManager.Service?)
    {
        SyncManager.shared.reset(for: service) { (result) in
            DispatchQueue.main.async {
                do
                {
                    try result.get()
                    
                    let previousService = self.selectedSyncingService
                    self.selectedSyncingService = service
                    
                    // Set to non-nil if we later authenticate.
                    Settings.syncingService = nil
                                        
                    if (previousService == nil && service != nil) || (previousService != nil && service == nil)
                    {
                        #if os(tvOS)
                        self.tableView.reloadData()
                        #else
                        self.tableView.reloadSections(IndexSet(integersIn: Section.service.rawValue ... Section.authenticate.rawValue), with: .fade)
                        #endif
                    }
                    else
                    {
                        self.tableView.reloadData()
                    }
                }
                catch
                {
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Change Syncing Service", comment: ""), error: error)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}

private extension SyncingServicesViewController
{
    func isSectionHidden(_ section: Section) -> Bool
    {
        #if os(iOS)
        switch section
        {
        case .service: return !self.syncingEnabledSwitch.isOn
        case .account: return !self.syncingEnabledSwitch.isOn || SyncManager.shared.coordinator?.account == nil
        case .authenticate: return !self.syncingEnabledSwitch.isOn
        case .voucher:
            // only available post-auth
            return !self.syncingEnabledSwitch.isOn || SyncManager.shared.coordinator?.account == nil
        default: return false
        }
        #elseif os(tvOS)
        switch section
        {
        case .service: return !self.isSyncingEnabled
        case .account: return !self.isSyncingEnabled || SyncManager.shared.coordinator?.account == nil
        case .authenticate:
             // cannot signin on tvOS, but need option to signout once authenticated through voucher
            return !(self.isSyncingEnabled && SyncManager.shared.coordinator?.account != nil)
        case .voucher: return !(self.isSyncingEnabled && SyncManager.shared.coordinator?.account == nil)
        default: return false
        }
        #endif
    }
}

extension SyncingServicesViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .syncing:
            cell.textLabel?.text = NSLocalizedString("Syncing", comment: "")
            #if os(tvOS)
            cell.detailTextLabel?.text = self.isSyncingEnabled
                ? NSLocalizedString("On", comment: "")
                : NSLocalizedString("Off", comment: "")
            #endif
            
        case .service:
            let service = SyncManager.Service.allCases[indexPath.row]
            cell.accessoryType = (service == self.selectedSyncingService) ? .checkmark : .none
            
        case .account:
            guard let account = SyncManager.shared.coordinator?.account else { return cell }
            
            let row = AccountRow(rawValue: indexPath.row)!
            switch row
            {
            case .name: cell.textLabel?.text = account.name
            case .emailAddress: cell.textLabel?.text = account.emailAddress
            }
            
        case .authenticate:
            if SyncManager.shared.coordinator?.account != nil
            {
                cell.textLabel?.textColor = .red
                cell.textLabel?.text = NSLocalizedString("Sign Out", comment: "")
            }
            else
            {
                cell.textLabel?.textColor = .deltaPurple
                cell.textLabel?.text = NSLocalizedString("Sign In", comment: "")
            }
            
        case .voucher:
            var mainText = ""
            var detailText = ""
            #if os(tvOS)
            switch voucherState {
            case .offline:
                mainText = "Start"
                detailText = "❌ Not Searching"
            case .online:
                mainText = "Stop"
                detailText = "📡 Searching for Voucher Servers..."
            case .waitingForConnection:
                mainText = "Stop"
                detailText = "😴 Not Connected Yet"
            case .connected:
                mainText = "Stop"
                detailText = "✅ Connected to '\(connectedClientName ?? "unknown")'"
            }
            #else
            switch voucherState {
            case .offline:
                mainText = "Start"
                detailText = "❌ Server Offline"
            case .online:
                mainText = "Stop"
                detailText = "✅ Server Online"
            case .waitingForConnection:
                mainText = "Stop"
                detailText = "📡 Waiting for Connection..."
            case .connected:
                mainText = "Stop"
                detailText = "✅ Connected"
            }
            #endif
            cell.textLabel?.text = NSLocalizedString(mainText, comment: "")
            cell.detailTextLabel?.text = NSLocalizedString(detailText, comment: "")
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch Section.allCases[indexPath.section]
        {
        case .syncing:
            #if os(tvOS)
            toggleSyncing()
            #else
            break // handled by ib outlet
            #endif
            
        case .service:
            let syncingService = SyncManager.Service.allCases[indexPath.row]
            guard syncingService != self.selectedSyncingService else { return }
            
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to change sync services?", comment: ""), message: NSLocalizedString("Switching back later may result in conflicts that must be resolved manually.", comment: ""), preferredStyle: .actionSheet)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Change Sync Service", comment: ""), style: .destructive, handler: { (action) in
                    self.changeService(to: syncingService)
                }))
                
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                self.changeService(to: syncingService)
            }
            
        case .account: break
            
        case .authenticate:            
            if SyncManager.shared.coordinator?.account != nil
            {
                let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to sign out?", comment: ""), message: NSLocalizedString("Signing in again later may result in conflicts that must be resolved manually.", comment: ""), preferredStyle: .actionSheet)
                alertController.addAction(.cancel)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Sign Out", comment: ""), style: .destructive) { (action) in
                    SyncManager.shared.deauthenticate { (result) in
                        DispatchQueue.main.async {
                            do
                            {
                                try result.get()
                                #if os(tvOS)
                                self.isSyncingEnabled = false
                                #endif
                                self.tableView.reloadData()
                                
                                Settings.syncingService = nil
                            }
                            catch
                            {
                                let alertController = UIAlertController(title: NSLocalizedString("Failed to Sign Out", comment: ""), error: error)
                                self.present(alertController, animated: true, completion: nil)
                            }
                        }
                    }
                })
                
                self.present(alertController, animated: true, completion: nil)
            }
            else
            {
                SyncManager.shared.authenticate(presentingViewController: self) { (result) in
                    DispatchQueue.main.async {
                        do
                        {
                            _ = try result.get()
                            self.tableView.reloadData()
                            
                            Settings.syncingService = self.selectedSyncingService
                        }
                        catch GeneralError.cancelled.self
                        {
                            // Ignore
                        }
                        catch
                        {
                            let alertController = UIAlertController(title: NSLocalizedString("Failed to Sign In", comment: ""), error: error)
                            alertController.addAction(.ok)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
        case .voucher:
            
            #if os(iOS)
            guard SyncManager.shared.coordinator?.account != nil else {
                return
            }
            #endif
            
            #if os(tvOS)
            guard self.selectedSyncingService == SyncManager.Service.dropbox else {
                let alertController = UIAlertController(title: NSLocalizedString("Option Not Available", comment: ""), message: NSLocalizedString("Delta TV syncing currently only supports Dropbox.", comment: ""), preferredStyle: .alert)
                alertController.addAction(.ok)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            #endif
            
            toggleVoucher()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        
        switch section
        {
        case let section where self.isSectionHidden(section): return 0
        case .account where SyncManager.shared.coordinator?.account?.emailAddress == nil: return 1
        default: return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
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
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
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
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
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
        let section = Section.allCases[section]
        
        if self.isSectionHidden(section)
        {
            return 1
        }
        else
        {
            return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
}

#if os(tvOS)
extension SyncingServicesViewController: VoucherClientDelegate {
    func voucherClient(_ client: VoucherClient, didUpdateSearching isSearching: Bool) {
        self.voucherState = VoucherState.offline
        if isSearching {
            self.voucherState = VoucherState.online
        }

        self.tableView.reloadData()
    }

    func voucherClient(_ client: VoucherClient, didUpdateConnectionToServer isConnectedToServer: Bool, serverName: String?) {
        self.connectedClientName = serverName
        self.voucherState = VoucherState.waitingForConnection
        if isConnectedToServer {
            self.voucherState = VoucherState.connected
        }

        self.tableView.reloadData()
    }
}
#elseif os(iOS)
extension SyncingServicesViewController: VoucherServerDelegate {
    func voucherServer(_ server: VoucherServer, didUpdateAdvertising isAdvertising: Bool) {
        self.voucherState = VoucherState.offline
        if (isAdvertising) {
            self.voucherState = VoucherState.online
        }
        
        self.tableView.reloadSections(IndexSet(integer: Section.voucher.rawValue), with: .none)
    }

    func voucherServer(_ server: VoucherServer, didUpdateConnectionToClient isConnectedToClient: Bool) {
        self.voucherState = VoucherState.waitingForConnection
        if (isConnectedToClient) {
            self.voucherState = VoucherState.connected
        }
        
        self.tableView.reloadSections(IndexSet(integer: Section.voucher.rawValue), with: .none)
    }
}
#endif
