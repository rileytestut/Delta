//
//  Bundle+AppIconImage.swift
//  Delta
//
//  Created by Chris Rittenhouse on 7/20/23.
//  Copyright © 2023 LitRitt. All rights reserved.
//

import UIKit

extension Bundle
{
    static func appIcon(for icon: AppIcon = .normal) -> UIImage? {
        guard let appIcons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any] else { return nil }
        
        switch icon
        {
        case .normal:
            guard let primaryAppIcon = appIcons["CFBundlePrimaryIcon"] as? [String: Any],
                  let appIconFiles = primaryAppIcon["CFBundleIconFiles"] as? [String],
                  let appIcon = appIconFiles.first else { return nil }
            
            return UIImage(named:appIcon)
            
        default:
            guard let alternateAppIcons = appIcons["CFBundleAlternateIcons"] as? [String: Any],
                  let alternateAppIcon = alternateAppIcons[icon.assetName] as? [String: Any],
                  let appIconFiles = alternateAppIcon["CFBundleIconFiles"] as? [String],
                  let appIcon = appIconFiles.first else { return nil }
            
            return UIImage(named:appIcon)
        }
    }
}
