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
    case inverted = "Inverted"
    case gba4ios = "GBA4iOS"
    case skin = "Controller Skin"
    case pixelated = "Pixelated"
    
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
        case .inverted: return "IconInverted"
        case .gba4ios: return "IconGBA4iOS"
        case .skin: return "IconSkin"
        case .pixelated: return "IconPixelated"
        }
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
        }.displayInline()
    })
    var icon: AppIcon = .normal
}
