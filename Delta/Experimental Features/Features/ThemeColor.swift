//
//  ThemeColor.swift
//  Delta
//
//  Created by Chris Rittenhouse on 7/21/23.
//  Copyright © 2023 LitRitt. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum ThemeColor: String, CaseIterable, CustomStringConvertible, Identifiable
{
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case teal = "Teal"
    case blue = "Blue"
    case purple = "Purple"
    
    var description: String {
        return self.rawValue
    }
    
    var id: String {
        return self.rawValue
    }
}

extension ThemeColor: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
}

extension Color: LocalizedOptionValue
{
    public var localizedDescription: Text {
        Text(self.description)
    }
}

struct ThemeColorOptions
{
    @Option(name: "Preset Color",
            description: "Choose the accent color of the app from a list of preset colors.",
            values: ThemeColor.allCases)
    var presetColor: ThemeColor = .purple
    
    @Option(name: "Use Custom Color",
            description: "Use a custom color instead of one of the presets.")
    var useCustom: Bool = false
    
    @Option(name: "Custom Color",
            description: "Select a custom color to use.",
            detailView: { value in
        ColorPicker("Custom Color", selection: value, supportsOpacity: false)
            .displayInline()
    })
    var customColor: Color = Color(red: 253/255, green: 110/255, blue: 0/255)
}
