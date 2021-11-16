//
//  ProcessInfo+JIT.swift
//  Delta
//
//  Created by Riley Testut on 9/14/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit

private let CS_OPS_STATUS: UInt32 = 0 /* OK */
private let CS_DEBUGGED: UInt32   = 0x10000000  /* Process is or has been attached to debugger. */

@_silgen_name("csops")
func csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int

extension ProcessInfo
{
    static var isJITDisabled = false
    
    var isDebugging: Bool {
        var flags: UInt32 = 0
        let result = csops(getpid(), CS_OPS_STATUS, &flags, MemoryLayout<UInt32>.size)
        
        let isDebugging = result == 0 && (flags & CS_DEBUGGED == CS_DEBUGGED)
        return isDebugging
    }
    
    var isJITAvailable: Bool {
        guard UIDevice.current.supportsJIT && !ProcessInfo.isJITDisabled else { return false }
        
        let ios14_4 = OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0)
        if #available(iOS 14.2, *), !ProcessInfo.processInfo.isOperatingSystemAtLeast(ios14_4)
        {
            // JIT is always available on supported devices running iOS 14.2 - 14.3.
            return true
        }
        
        return self.isDebugging
    }
}
