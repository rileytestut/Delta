//
//  SystemBIOS.swift
//  Delta
//
//  Created by Riley Testut on 1/19/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation

import MelonDSDeltaCore

protocol SystemBIOS
{
    var fileURL: URL { get }
    var filename: String { get }
    
    var expectedMD5Hash: String? { get }
    
    // RangeSet would be preferable, but it's not in Swift stdlib yet.
    @available(iOS 13, *)
    var validFileSizes: Set<ClosedRange<Measurement<UnitInformationStorage>>> { get }
}

extension SystemBIOS
{
    var filename: String {
        return self.fileURL.lastPathComponent
    }
}

enum DSBIOS: SystemBIOS, CaseIterable
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
            // 128KB, 256KB, or 512KB
            return Set([128, 256, 512].map { Measurement(value: $0, unit: .kibibytes) }.map { $0...$0 })
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
        switch self
        {
        case .bios7: return MelonDSEmulatorBridge.shared.dsiBIOS7URL
        case .bios9: return MelonDSEmulatorBridge.shared.dsiBIOS9URL
        case .firmware: return MelonDSEmulatorBridge.shared.dsiFirmwareURL
        case .nand: return MelonDSEmulatorBridge.shared.dsiNANDURL
        }
    }
    
    var expectedMD5Hash: String? {
        switch self
        {
        case .bios7: return "559dae4ea78eb9d67702c56c1d791e81"
        case .bios9: return "87b665fce118f76251271c3732532777"
        case .firmware: return nil
        case .nand: return nil
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
