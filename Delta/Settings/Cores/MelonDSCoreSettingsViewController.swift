//
//  MelonDSCoreSettingsViewController.swift
//  Delta
//
//  Created by Riley Testut on 4/13/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices
import MobileCoreServices

import DeltaCore
import MelonDSDeltaCore

//import struct DSDeltaCore.DS

import Roxas

private extension MelonDSCoreSettingsViewController
{
    enum Section: Int
    {
        case general
        case bios
        case changeCore
    }
    
    enum BIOS: Int
    {
        case bios7
        case bios9
        case firmware
        
        var fileURL: URL {
            switch self
            {
            case .bios7: return MelonDSEmulatorBridge.shared.bios7URL
            case .bios9: return MelonDSEmulatorBridge.shared.bios9URL
            case .firmware: return MelonDSEmulatorBridge.shared.firmwareURL
            }
        }
    }
}

class MelonDSCoreSettingsViewController: UITableViewController
{
    private var importDestinationURL: URL?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let navigationController = self.navigationController, navigationController.viewControllers.first != self
        {
            self.navigationItem.rightBarButtonItem = nil
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(MelonDSCoreSettingsViewController.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        if let core = Delta.registeredCores[.ds]
        {
            DatabaseManager.shared.performBackgroundTask { (context) in
                // Prepare database in case we changed/updated cores.
                DatabaseManager.shared.prepare(core, in: context)
                context.saveWithErrorLogging()
            }
        }
    }
}

private extension MelonDSCoreSettingsViewController
{
    func openMetadataURL(for key: DeltaCoreMetadata.Key)
    {
        guard let metadata = Settings.preferredCore(for: .ds)?.metadata else { return }
        
        let item = metadata[key]
        guard let url = item?.url else {
            if let indexPath = self.tableView.indexPathForSelectedRow
            {
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
            
            return
        }
        
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = .deltaPurple
        self.present(safariViewController, animated: true, completion: nil)
    }
    
    func locate(_ bios: BIOS)
    {
        self.importDestinationURL = bios.fileURL
        
        var supportedTypes = [kUTTypeItem as String, kUTTypeContent as String, "com.apple.macbinary-archive" /* System UTI for .bin */]
        
        // Explicitly support files with .bin and .rom extensions.
        if let binTypes = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, "bin" as CFString, nil)?.takeRetainedValue()
        {
            let types = (binTypes as NSArray).map { $0 as! String }
            supportedTypes.append(contentsOf: types)
        }
            
        if let romTypes = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, "rom" as CFString, nil)?.takeRetainedValue()
        {
            let types = (romTypes as NSArray).map { $0 as! String }
            supportedTypes.append(contentsOf: types)
        }
        
        let documentPicker = UIDocumentPickerViewController(documentTypes: supportedTypes, in: .import)
        documentPicker.delegate = self
        
        if #available(iOS 13.0, *)
        {
            documentPicker.overrideUserInterfaceStyle = .dark
        }
        
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func changeCore()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Change Emulator Core", comment: ""), message: NSLocalizedString("Save states are not compatible between different emulator cores. Make sure to use in-game saves in order to keep using your save data.\n\nYour existing save states will not be deleted and will be available whenever you switch cores again.", comment: ""), preferredStyle: .actionSheet)
        
//        var desmumeActionTitle = DS.core.metadata?.name.value ?? DS.core.name
        var melonDSActionTitle = MelonDS.core.metadata?.name.value ?? MelonDS.core.name
        
//        if Settings.preferredCore(for: .ds) == DS.core
//        {
//            desmumeActionTitle += " ✓"
//        }
//        else
//        {
            melonDSActionTitle += " ✓"
//        }
        
//        alertController.addAction(UIAlertAction(title: desmumeActionTitle, style: .default, handler: { (action) in
//            Settings.setPreferredCore(DS.core, for: .ds)
//            self.tableView.reloadData()
//        }))
        
        alertController.addAction(UIAlertAction(title: melonDSActionTitle, style: .default, handler: { (action) in
            Settings.setPreferredCore(MelonDS.core, for: .ds)
            self.tableView.reloadData()
        }))
        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
        
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.tableView.reloadData()
    }
}

extension MelonDSCoreSettingsViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section(rawValue: indexPath.section)!
        {
        case .general:
            let key = DeltaCoreMetadata.Key.allCases[indexPath.row]
            let item = Settings.preferredCore(for: .ds)?.metadata?[key]
            
            cell.detailTextLabel?.text = item?.value ?? NSLocalizedString("-", comment: "")
            cell.detailTextLabel?.textColor = .gray
            
            if item?.url != nil
            {
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
            else
            {
                cell.accessoryType = .none
                cell.selectionStyle = .none
            }
            
            cell.contentView.isHidden = (item == nil)
            
        case .bios:
            let bios = BIOS(rawValue: indexPath.row)!
            
            if FileManager.default.fileExists(atPath: bios.fileURL.path)
            {
                cell.accessoryType = .checkmark
                cell.detailTextLabel?.text = nil
                cell.detailTextLabel?.textColor = .gray
            }
            else
            {
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = NSLocalizedString("Required", comment: "")
                cell.detailTextLabel?.textColor = .red
            }
            
            cell.selectionStyle = .default
            
        case .changeCore: break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        guard let core = Settings.preferredCore(for: .ds) else { return }
        
        let key = DeltaCoreMetadata.Key.allCases[indexPath.row]
        let lastKey = DeltaCoreMetadata.Key.allCases.reversed().first { core.metadata?[$0] != nil }
        
        if key == lastKey
        {
            // Hide separator for last visible row in case we've hidden additional rows.
            cell.separatorInset.left = 0
        }
        else
        {
            cell.separatorInset.left = self.view.layoutMargins.left
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .general:
            let key = DeltaCoreMetadata.Key.allCases[indexPath.row]
            self.openMetadataURL(for: key)
            
        case .bios:
            let bios = BIOS(rawValue: indexPath.row)!
            self.locate(bios)
            
        case .changeCore:
            self.changeCore()
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch Section(rawValue: section)!
        {
        case .bios:
            guard Settings.preferredCore(for: .ds) == MelonDS.core else { return nil }
            
        default: break
        }
        
        return super.tableView(tableView, titleForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        switch Section(rawValue: section)!
        {
        case .bios:
            guard Settings.preferredCore(for: .ds) == MelonDS.core else { return nil }
            
        default: break
        }
        
        return super.tableView(tableView, titleForFooterInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .general:
            let key = DeltaCoreMetadata.Key.allCases[indexPath.row]
            guard Settings.preferredCore(for: .ds)?.metadata?[key] != nil else { return  0 }
            
        case .bios:
            guard Settings.preferredCore(for: .ds) == MelonDS.core else { return 0 }
            
        default: break
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        switch Section(rawValue: section)!
        {
        case .bios:
            guard Settings.preferredCore(for: .ds) == MelonDS.core else { return 1 }
            
        default: break
        }
        
        return super.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        switch Section(rawValue: section)!
        {
        case .bios:
            guard Settings.preferredCore(for: .ds) == MelonDS.core else { return 1 }
            
        default: break
        }
        
        return super.tableView(tableView, heightForFooterInSection: section)
    }
}

extension MelonDSCoreSettingsViewController: UIDocumentPickerDelegate
{
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self.importDestinationURL = nil
        self.tableView.reloadData() // Reloading index path causes cell to disappear...
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        defer {
            self.importDestinationURL = nil
            self.tableView.reloadData() // Reloading index path causes cell to disappear...
        }
        
        guard let fileURL = urls.first, let destinationURL = self.importDestinationURL else { return }
        
        do
        {
            try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true)
        }
        catch
        {
            let title = String(format: NSLocalizedString("Could not import %@.", comment: ""), fileURL.lastPathComponent)

            let alertController = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(.ok)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
