//
//  OSLog+Delta.swift
//  Delta
//
//  Created by Riley Testut on 8/10/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

@_exported import OSLog

extension OSLog.Category
{
    static let main = "Main"
    static let database = "Database"
    static let purchases = "Purchases"
}

extension Logger
{
    static let deltaSubsystem = "com.rileytestut.Delta"
    
    static let main = Logger(subsystem: deltaSubsystem, category: OSLog.Category.main)
    static let database = Logger(subsystem: deltaSubsystem, category: OSLog.Category.database)
    static let purchases = Logger(subsystem: deltaSubsystem, category: OSLog.Category.purchases)
}

@available(iOS 15, *)
extension OSLogEntryLog.Level
{
    var localizedName: String {
        switch self
        {
        case .undefined: return NSLocalizedString("Undefined", comment: "")
        case .debug: return NSLocalizedString("Debug", comment: "")
        case .info: return NSLocalizedString("Info", comment: "")
        case .notice: return NSLocalizedString("Notice", comment: "")
        case .error: return NSLocalizedString("Error", comment: "")
        case .fault: return NSLocalizedString("Fault", comment: "")
        @unknown default: return NSLocalizedString("Unknown", comment: "")
        }
    }
}
