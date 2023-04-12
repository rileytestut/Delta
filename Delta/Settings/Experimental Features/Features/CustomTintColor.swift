//
//  CustomTintColor.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum TintColor: String, CaseIterable, Identifiable
{
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    
    var id: Self { self }
    
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

extension TintColor: LocalizedOptionValue
{
    var localizedDescription: Text {
        switch self
        {
        case .red: return Text("Red")
        case .orange: return Text("Orange")
        case .yellow: return Text("Yellow")
        case .green: return Text("Green")
        case .blue: return Text("Blue")
        case .purple: return Text("Purple")
        }
    }
}

struct CustomTintColorOptions
{
    @Option(name: "Tint Color", detailView: { CustomTintColorView(tintColor: $0) })
    var value: TintColor = .purple
    
//    @Option(name: "Tint Color", detailView: { (binding) in
//        Circle()
//            .fill(Color.purple)
//            .frame(width: 200, height: 200)
////        .displayInline()
//    })
//    var value: TintColor = .purple
    
    @Option(name: "Respect Dark Mode")
    var respectDarkMode: Bool = true
}

private struct CustomTintColorView: View
{
    @Binding
    var tintColor: TintColor

    var body: some View {
        Picker("Tint Color", selection: $tintColor.animation()) {
            ForEach(TintColor.allCases) { tintColor in
                HStack(spacing: 8) {
                    Circle()
                        .fill(tintColor.color)
                        .frame(width: 44, height: 44)
                    
                    tintColor.localizedDescription
                }
            }
        }
        .pickerStyle(.inline)
    }
}
