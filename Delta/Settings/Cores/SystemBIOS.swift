//
//  SystemBIOS.swift
//  Delta
//
//  Created by Riley Testut on 1/19/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation

//import MelonDSDeltaCore

protocol SystemBIOS
{
    var fileURL: URL { get }
    var filename: String { get }
    
    var expectedMD5Hash: String? { get }
    var unsupportedMD5Hashes: Set<String> { get }
    
    // RangeSet would be preferable, but it's not in Swift stdlib yet.
    @available(iOS 13, *)
    var validFileSizes: Set<ClosedRange<Measurement<UnitInformationStorage>>> { get }
}

extension SystemBIOS
{
    var filename: String {
        return self.fileURL.lastPathComponent
    }
    
    var expectedMD5Hash: String? {
        return nil
    }
    
    var unsupportedMD5Hashes: Set<String> {
        return []
    }
}

enum DSBIOS: SystemBIOS, CaseIterable
{
    case bios7
    case bios9
    case firmware
    
    var fileURL: URL {
//        switch self
//        {
//        case .bios7: return MelonDSEmulatorBridge.shared.bios7URL
//        case .bios9: return MelonDSEmulatorBridge.shared.bios9URL
//        case .firmware: return MelonDSEmulatorBridge.shared.firmwareURL
//        }
        return Bundle.main.bundleURL
    }
    
    var expectedMD5Hash: String? {
        switch self
        {
        case .bios7: return "df692a80a5b1bc90728bc3dfc76cd948"
        case .bios9: return "a392174eb3e572fed6447e956bde4b25"
        case .firmware: return nil
        }
    }
    
    @available(iOS 13, *)
    var validFileSizes: Set<ClosedRange<Measurement<UnitInformationStorage>>> {
        // From http://melonds.kuribo64.net/faq.php
        switch self
        {
        case .bios7:
            // 16KB
            return Set([16].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
        case .bios9:
            // 4KB
            return Set([4].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
        case .firmware:
            // 256KB or 512KB
            // DSi/3DS 128KB firmwares technically work but aren't bootable, so we treat them as unsupported.
            return Set([256, 512].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
        }
    }
}

enum DSiBIOS: SystemBIOS, CaseIterable
{
    case bios7
    case bios9
    case firmware
    case nand
    
    var fileURL: URL {
//        switch self
//        {
//        case .bios7: return MelonDSEmulatorBridge.shared.dsiBIOS7URL
//        case .bios9: return MelonDSEmulatorBridge.shared.dsiBIOS9URL
//        case .firmware: return MelonDSEmulatorBridge.shared.dsiFirmwareURL
//        case .nand: return MelonDSEmulatorBridge.shared.dsiNANDURL
//        }
        return Bundle.main.bundleURL
    }
    
    var unsupportedMD5Hashes: Set<String> {
        switch self
        {
        case .bios7:
            return [
                "c8b9fe70f1ef5cab8e55540cd1c13dc8", // BIOSDSI7.ROM
                "3fbb3f39bd9a96e5d743f138bd4b9907", // BIOSDSI9.ROM
                "87b665fce118f76251271c3732532777", // bios9i.bin
            ]
        
        case .bios9:
            return [
                "c8b9fe70f1ef5cab8e55540cd1c13dc8", // BIOSDSI7.ROM
                "3fbb3f39bd9a96e5d743f138bd4b9907", // BIOSDSI9.ROM
                "559dae4ea78eb9d67702c56c1d791e81", // bios7i.bin
            ]
            
        case .firmware: return []
        case .nand: return []
        }
    }
    
    @available(iOS 13, *)
    var validFileSizes: Set<ClosedRange<Measurement<UnitInformationStorage>>> {
        // From http://melonds.kuribo64.net/faq.php
        switch self
        {
        case .bios7:
            // 64KB
            return Set([64].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
            
        case .bios9:
            // 64KB
            return Set([64].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
            
        case .firmware:
            // 128KB
            return Set([128].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
            
        case .nand:
            // 200MB - 300MB
            return Set([200...300].map { Measurement(value: $0.lowerBound, unit: .mebibytes) ... Measurement(value: $0.upperBound, unit: .mebibytes) })
        }
    }
}
