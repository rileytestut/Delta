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
import CryptoKit

import DeltaCore
import MelonDSDeltaCore

import Roxas

private extension MelonDSCoreSettingsViewController
{
    enum Section: Int
    {
        case general
        case performance
        case dsBIOS
        case dsiBIOS
    }
    
    @available(iOS 13, *)
    enum BIOSError: LocalizedError
    {
        case unknownSize(URL)
        case incorrectHash(URL, hash: String, expectedHash: String)
        case unsupportedHash(URL, hash: String)
        case incorrectSize(URL, size: Int, validSizes: Set<ClosedRange<Measurement<UnitInformationStorage>>>)
                
        private static let byteFormatter: ByteCountFormatter = {
            let formatter = ByteCountFormatter()
            formatter.includesActualByteCount = true
            formatter.countStyle = .binary
            return formatter
        }()
        
        var errorDescription: String? {
            switch self
            {
            case .unknownSize(let fileURL):
                return String(format: NSLocalizedString("%@’s size could not be determined.", comment: ""), fileURL.lastPathComponent)
                
            case .incorrectHash(let fileURL, let md5Hash, let expectedHash):
                return String(format: NSLocalizedString("%@‘s checksum does not match the expected checksum.\n\nChecksum:\n%@\n\nExpected:\n%@", comment: ""), fileURL.lastPathComponent, md5Hash, expectedHash)
                
            case .unsupportedHash(let fileURL, let md5Hash):
                return String(format: NSLocalizedString("%@ is not compatible with this version of Delta.\n\nChecksum:\n%@", comment: ""), fileURL.lastPathComponent, md5Hash)
                
            case .incorrectSize(let fileURL, let size, let validSizes):
                let actualSize = BIOSError.byteFormatter.string(fromByteCount: Int64(size))
                
                if let range = validSizes.first, validSizes.count == 1
                {
                    if range.lowerBound == range.upperBound
                    {
                        // Single value
                        let expectedSize = BIOSError.byteFormatter.string(fromByteCount: Int64(range.lowerBound.converted(to: .bytes).value))
                        return String(format: NSLocalizedString("%@ is %@, but expected size is %@.", comment: ""), fileURL.lastPathComponent, actualSize, expectedSize)
                    }
                    else
                    {
                        // Range
                        BIOSError.byteFormatter.includesActualByteCount = false
                        defer { BIOSError.byteFormatter.includesActualByteCount = true }
                        
                        let lowerBound = BIOSError.byteFormatter.string(fromByteCount: Int64(range.lowerBound.converted(to: .bytes).value))
                        let upperBound = BIOSError.byteFormatter.string(fromByteCount: Int64(range.upperBound.converted(to: .bytes).value))
                        return String(format: NSLocalizedString("%@ is %@, but expected size is between %@ and %@.", comment: ""), fileURL.lastPathComponent, actualSize, lowerBound, upperBound)
                    }
                }
                else
                {
                    var description = String(format: NSLocalizedString("%@ is %@, but expected sizes are:", comment: ""), fileURL.lastPathComponent, actualSize) + "\n"
                    
                    let sortedRanges = validSizes.sorted(by: { $0.lowerBound < $1.lowerBound })
                    for range in sortedRanges
                    {
                        // Assume BIOS with multiple valid file sizes don't use (>1 count) ranges.
                        description += "\n" + BIOSError.byteFormatter.string(fromByteCount: Int64(range.lowerBound.converted(to: .bytes).value))
                    }
                    
                    return description
                }
            }
        }
        
        var recoverySuggestion: String? {
            return NSLocalizedString("Please choose a different BIOS file.", comment: "")
        }
    }
}

class MelonDSCoreSettingsViewController: UITableViewController
{
    private var importingBIOS: SystemBIOS?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if let navigationController = self.navigationController, navigationController.viewControllers.first != self
        {
            self.navigationItem.rightBarButtonItem = nil
        }
        
        if #available(iOS 15, *)
        {
            self.tableView.register(AttributedHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: AttributedHeaderFooterView.reuseIdentifier)
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
    func isSectionHidden(_ section: Section) -> Bool
    {
        #if BETA
        let isBeta = true
        #else
        let isBeta = false
        #endif
        
        switch section
        {
        case .performance:
            // Hide AltJIT section for public builds.
            // guard isBeta else { return true }
            //
            // guard Settings.preferredCore(for: .ds) == MelonDS.core else { return true }
            // return !UIDevice.current.supportsJIT
            
            // AltJIT not currently supported with melonDS 0.9.5.
            return true
            
        case .dsiBIOS where !isBeta:
            // Using public Delta version, which doesn't support DSi (yet).
            return true
            
        default: return false
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
    
    func locate<BIOS: SystemBIOS>(_ bios: BIOS)
    {
        self.importingBIOS = bios
        
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
    
    @IBAction func toggleAltJITEnabled(_ sender: UISwitch)
    {
        Settings.isAltJITEnabled = sender.isOn
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.tableView.reloadData()
    }
}

extension MelonDSCoreSettingsViewController
{
    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int
    {
        let section = Section(rawValue: sectionIndex)!
        
        switch section
        {
        case _ where isSectionHidden(section): return 0
        case .general:
            guard let core = Settings.preferredCore(for: .ds) else { break }
            
            let validKeys = DeltaCoreMetadata.Key.allCases.filter { core.metadata?[$0] != nil }
            return validKeys.count
            
        default: break
        }
        
        return super.tableView(tableView, numberOfRowsInSection: sectionIndex)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section(rawValue: indexPath.section)!
        {
        case .general:
            guard let core = Settings.preferredCore(for: .ds) else { break }
            let filteredKeys = DeltaCoreMetadata.Key.allCases.filter { core.metadata?[$0] != nil }
            
            let key = filteredKeys[indexPath.row]
            cell.textLabel?.text = key.localizedName
            
            let item = core.metadata?[key]
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
            
        case .performance:
            let cell = cell as! SwitchTableViewCell
            cell.switchView.isOn = Settings.isAltJITEnabled
            
        case .dsBIOS:
            let bios = DSBIOS.allCases[indexPath.row]
            
            if FileManager.default.fileExists(atPath: bios.fileURL.path)
            {
                cell.accessoryType = .checkmark
                cell.detailTextLabel?.text = nil
                cell.detailTextLabel?.textColor = .gray
            }
            else
            {
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = NSLocalizedString("Optional", comment: "")
                cell.detailTextLabel?.textColor = .deltaPurple
            }
            
            cell.selectionStyle = .default
            
        case .dsiBIOS:
            let bios = DSiBIOS.allCases[indexPath.row]
            
            if FileManager.default.fileExists(atPath: bios.fileURL.path)
            {
                cell.accessoryType = .checkmark
                cell.detailTextLabel?.text = nil
                cell.detailTextLabel?.textColor = .gray
            }
            else
            {
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = NSLocalizedString("Optional", comment: "")
                cell.detailTextLabel?.textColor = .deltaPurple
            }
            
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        switch Section(rawValue: indexPath.section)!
        {
        case .general:
            guard let core = Settings.preferredCore(for: .ds) else { break }
            let filteredKeys = DeltaCoreMetadata.Key.allCases.filter { core.metadata?[$0] != nil }
            
            let key = filteredKeys[indexPath.row]
            self.openMetadataURL(for: key)
            
        case .dsBIOS:
            let bios = DSBIOS.allCases[indexPath.row]
            self.locate(bios)
            
        case .dsiBIOS:
            let bios = DSiBIOS.allCases[indexPath.row]
            self.locate(bios)
            
        case .performance: break
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
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .dsBIOS, .dsiBIOS:
            guard #available(iOS 15, *) else { break }
            return nil
            
        default: break
        }
        
        return super.tableView(tableView, titleForFooterInSection: section.rawValue)
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return nil }
        
        switch section
        {
        case .dsBIOS, .dsiBIOS:
            guard #available(iOS 15, *), let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: AttributedHeaderFooterView.reuseIdentifier) as? AttributedHeaderFooterView else { break }
            
            let systemName = (section == .dsiBIOS) ? String(localized: "DSi") : String(localized: "DS")
            
            var attributedText = AttributedString(localized: "Delta requires these BIOS files to emulate certain Nintendo \(systemName) features.")
            attributedText += " "
            
            var learnMore = AttributedString(localized: "Learn more…")
            learnMore.link = URL(string: "https://faq.deltaemulator.com/getting-started/nintendo-ds-bios-files")
            attributedText += learnMore
            
            footerView.attributedText = attributedText
            
            return footerView
            
        default: break
        }
        
        return super.tableView(tableView, viewForFooterInSection: section.rawValue)
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
        case .dsBIOS, .dsiBIOS: return UITableView.automaticDimension
        default: return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat 
    {
        let section = Section(rawValue: section)!
        guard !isSectionHidden(section) else { return 1 }
        
        switch section
        {
        case .dsBIOS, .dsiBIOS: return 30
        default: return UITableView.automaticDimension
        }
    }
}

extension MelonDSCoreSettingsViewController: UIDocumentPickerDelegate
{
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self.importingBIOS = nil
        self.tableView.reloadData() // Reloading index path causes cell to disappear...
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        defer {
            self.importingBIOS = nil
            self.tableView.reloadData() // Reloading index path causes cell to disappear...
        }
        
        guard let fileURL = urls.first, let bios = self.importingBIOS else { return }
        
        defer { try? FileManager.default.removeItem(at: fileURL) }
        
        do
        {
            if #available(iOS 13.0, *)
            {
                // Validate file size first (since that's easiest for users to understand).
                
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                guard let fileSize = attributes[.size] as? Int else { throw BIOSError.unknownSize(fileURL) }
                
                let measurement = Measurement<UnitInformationStorage>(value: Double(fileSize), unit: .bytes)
                guard bios.validFileSizes.contains(where: { $0.contains(measurement) }) else { throw BIOSError.incorrectSize(fileURL, size: fileSize, validSizes: bios.validFileSizes) }
                
                if bios.expectedMD5Hash != nil || !bios.unsupportedMD5Hashes.isEmpty
                {
                    // Only calculate hash if we need to.
                    
                    let data = try Data(contentsOf: fileURL)
                    
                    let md5Hash = Insecure.MD5.hash(data: data)
                    let hashString = md5Hash.compactMap { String(format: "%02x", $0) }.joined()
                    
                    if let expectedMD5Hash = bios.expectedMD5Hash
                    {
                        guard hashString == expectedMD5Hash else { throw BIOSError.incorrectHash(fileURL, hash: hashString, expectedHash: expectedMD5Hash) }
                    }
                    
                    guard !bios.unsupportedMD5Hashes.contains(hashString) else { throw BIOSError.unsupportedHash(fileURL, hash: hashString) }
                }
            }
            
            try FileManager.default.copyItem(at: fileURL, to: bios.fileURL, shouldReplace: true)
        }
        catch let error as NSError
        {
            let title = String(format: NSLocalizedString("Could not import %@.", comment: ""), bios.filename)

            var message = error.localizedDescription
            if let recoverySuggestion = error.localizedRecoverySuggestion
            {
                message += "\n\n" + recoverySuggestion
            }
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(.ok)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
