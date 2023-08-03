//
//  AlternateAppIcons.swift
//  Delta
//
//  Created by Chris Rittenhouse on 5/2/23.
//  Copyright © 2023 LitRitt. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum AppIcon: String, CaseIterable, CustomStringConvertible, Identifiable
{
    case normal = "Default"
    case gba4ios = "GBA4iOS"
    case inverted = "Inverted"
    case pixelated = "Pixelated"
    case skin = "Controller Skin"
    
    var description: String {
        return self.rawValue
    }
    
    var id: String {
        return self.rawValue
    }
    
    var author: String {
        switch self
        {
        case .normal: return "Caroline Moore"
        case .gba4ios: return "Paul Thorsen"
        case .inverted, .skin, .pixelated: return "LitRitt"
        }
    }
    
    var assetName: String {
        switch self
        {
        case .normal: return "AppIcon"
        case .gba4ios: return "IconGBA4iOS"
        case .inverted: return "IconInverted"
        case .pixelated: return "IconPixelated"
        case .skin: return "IconSkin"
        }
    }
}

extension AppIcon: Equatable
{
    static func == (lhs: AppIcon, rhs: AppIcon) -> Bool
    {
        return lhs.description == rhs.description
    }
}

extension AppIcon: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
}

struct AlternateAppIconOptions
{
    @Option(name: "Alternate App Icon",
            description: "Choose from alternate app icons created by the community.",
            detailView: { value in
        List {
            ForEach(AppIcon.allCases) { icon in
                HStack {
                    if icon == value.wrappedValue
                    {
                        Text("✓")
                    }
                    icon.localizedDescription
                    Text("- by \(icon.author)")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(uiImage: Bundle.appIcon(for: icon) ?? UIImage())
                        .cornerRadius(13)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    value.wrappedValue = icon
                }
            }
        }
        .onChange(of: value.wrappedValue) { _ in
            updateAppIcon()
        }
        .displayInline()
    })
    var icon: AppIcon = .normal
}

extension AlternateAppIconOptions
{
    static func updateAppIcon()
    {
        // Get current icon
        let currentIcon = UIApplication.shared.alternateIconName
        
        // Apply chosen icon if feature is enabled
        if ExperimentalFeatures.shared.alternateAppIcons.isEnabled
        {
            let icon = ExperimentalFeatures.shared.alternateAppIcons.icon
            
            // Only apply new icon if it's not already the current icon
            switch icon
            {
            case .normal: if currentIcon != nil { UIApplication.shared.setAlternateIconName(nil) } // Default app icon
            default: if currentIcon != icon.assetName { UIApplication.shared.setAlternateIconName(icon.assetName) } // Alternate app icon
            }
        }
        else
        {
            // Remove alternate icons if feature is disabled
            if currentIcon != nil { UIApplication.shared.setAlternateIconName(nil) }
        }
    }
}
