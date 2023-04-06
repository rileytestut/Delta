//
//  CustomTintColor.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import SwiftUI

enum TintColor: String, CaseIterable, Identifiable, CustomStringConvertible
{
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    
    var id: Self { self }
    
    var description: String {
        switch self
        {
        case .red: return NSLocalizedString("Red", comment: "")
        case .orange: return NSLocalizedString("Orange", comment: "")
        case .yellow: return NSLocalizedString("Yellow", comment: "")
        case .green: return NSLocalizedString("Green", comment: "")
        case .blue: return NSLocalizedString("Blue", comment: "")
        case .purple: return NSLocalizedString("Purple", comment: "")
        }
    }
    
    var color: Color {
        switch self
        {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

class CustomTintColor: ExperimentalFeature, ObservableObject
{
    static var settingsKey: String { "customTintColor" }

    var name: String { NSLocalizedString("Custom Tint Color", comment: "") }
    var description: String? { NSLocalizedString("Change the accent color of Delta.", comment: "") }

    @FeatureSetting(name: "Tint Color", key: "color", detailView: { CustomTintColorView(tintColor: $0) })
    var value: TintColor = .purple
}

private struct CustomTintColorView: View
{
    @Binding
    var tintColor: TintColor

    var body: some View {
        Picker("Fast Forward Speed", selection: $tintColor.animation()) {
            ForEach(TintColor.allCases) { tintColor in
                HStack(spacing: 8) {
                    Circle()
                        .fill(tintColor.color)
                        .frame(width: 44, height: 44)
                    
                    Text(tintColor.description)
                }
            }
        }
        .pickerStyle(.inline)
    }
}
