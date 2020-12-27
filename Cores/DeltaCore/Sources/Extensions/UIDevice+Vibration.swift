//
//  UIDevice+Vibration.swift
//  DeltaCore
//
//  Created by Riley Testut on 11/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import AudioToolbox

@_silgen_name("AudioServicesStopSystemSound")
func AudioServicesStopSystemSound(_ soundID: SystemSoundID)

// vibrationPattern parameter must be NSDictionary to prevent crash when bridging from Swift.Dictionary.
@_silgen_name("AudioServicesPlaySystemSoundWithVibration")
func AudioServicesPlaySystemSoundWithVibration(_ soundID: SystemSoundID, _ idk: Any?, _ vibrationPattern: NSDictionary)

public extension UIDevice
{
    enum FeedbackSupportLevel: Int
    {
        case unsupported
        case basic
        case feedbackGenerator
    }
}

public extension UIDevice
{
    var feedbackSupportLevel: FeedbackSupportLevel
    {
        guard let rawValue = self.value(forKey: "_feedbackSupportLevel") as? Int else { return .unsupported }
        
        let feedbackSupportLevel = FeedbackSupportLevel(rawValue: rawValue)
        return feedbackSupportLevel ?? .feedbackGenerator // We'll assume raw values greater than 2 still support UIFeedbackGenerator ¯\_(ツ)_/¯
    }
    
    var isVibrationSupported: Bool {
        #if (arch(i386) || arch(x86_64))
            // Return false for iOS simulator
            return false
        #else
            // All iPhones support some form of vibration, and potentially future non-iPhone devices will support taptic feedback
            return (self.model.hasPrefix("iPhone")) || self.feedbackSupportLevel != .unsupported
        #endif
    }
    
    func vibrate()
    {
        guard self.isVibrationSupported else { return }
        
        switch self.feedbackSupportLevel
        {
        case .unsupported:
            AudioServicesStopSystemSound(kSystemSoundID_Vibrate)
            
            var vibrationLength = 30
            
            if self.modelGeneration.hasPrefix("iPhone6")
            {
                // iPhone 5S has a weaker vibration motor, so we vibrate for 10ms longer to compensate
                vibrationLength = 40;
            }
            
            // Must use NSArray/NSDictionary to prevent crash.
            let pattern: [Any] = [false, 0, true, vibrationLength]
            let dictionary: [String: Any] = ["VibePattern": pattern, "Intensity": 1]
            
            AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary as NSDictionary)
        
        case .basic, .feedbackGenerator: AudioServicesPlaySystemSound(1519) // "peek" vibration
        }
    }
}

private extension UIDevice
{
    var modelGeneration: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        var modelGeneration: String!
        
        withUnsafePointer(to: &sysinfo.machine) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: Int(Mirror(reflecting: pointer.pointee).children.count), { (pointer) in
                modelGeneration = String(cString: pointer)
            })
        }
        
        return modelGeneration
    }
}
