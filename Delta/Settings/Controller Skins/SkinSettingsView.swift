//
//  SkinSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct SkinSettingsView: View
{
    @AppStorage(Settings.Name.translucentControllerSkinOpacity.rawValue)
    private var opacity: Double = 0.7
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Opacity") {
                        Text("\(Int(opacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $opacity, in: 0...1, step: 0.05)
                        .onChange(of: opacity) { _, newValue in
                            Settings.translucentControllerSkinOpacity = newValue
                        }
                        .sensoryFeedback(.selection, trigger: opacity)
                }
            } footer: {
                Text("Adjusts the transparency of on-screen controller skins.")
            }

            Section {
                ForEach(System.registeredSystems, id: \.self) { system in
                    NavigationLink(destination: PreferredControllerSkinsViewController.ViewRepresentable(system: system)) {
                        Text(system.localizedName)
                    }
                }
            } header: {
                Text("Systems")
            } footer: {
                Text("Customize the appearance of each system.")
            }
        }
        .tint(.accentColor)
        .navigationTitle("Skins")
        .navigationBarTitleDisplayMode(.inline)
    }
}
