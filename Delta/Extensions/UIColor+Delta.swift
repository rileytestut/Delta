//
//  UIColor+Delta.swift
//  Delta
//
//  Created by Riley Testut on 12/26/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

extension UIColor
{
    static let deltaPurple = UIColor(named: "Purple")!
    static let deltaDarkGray = UIColor(named: "DarkGray")!
    
    static var themeColor: UIColor
        {
            // Get theme color based on user Theme Color options if feature is enabled
            if Settings.experimentalFeatures.themeColor.isEnabled
            {
                // Use custom color if option is enabled
                if Settings.experimentalFeatures.themeColor.useCustom
                {
                    guard let color = Settings.experimentalFeatures.themeColor.customColor.cgColor else { return .deltaPurple }
                    
                    return UIColor(cgColor: color)
                }
                // Use preset color if custom color option is disabled
                else
                {
                    switch Settings.experimentalFeatures.themeColor.presetColor
                    {
                    case .pink:
                        return UIColor.systemPink
                    case .red:
                        return UIColor.systemRed
                    case .orange:
                        return UIColor.systemOrange
                    case .yellow:
                        return UIColor.systemYellow
                    case .green:
                        return UIColor.systemGreen
                    case .teal:
                        return UIColor.systemTeal
                    case .blue:
                        return UIColor.systemBlue
                    case .purple:
                        return deltaPurple
                    }
                }
            }
            // Use default app accent color if Theme Color feature is disabled
            else
            {
                return deltaPurple
            }
        }
}
