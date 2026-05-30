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
    // @State instead of @AppStorage so the slider drags continuously.
    @SwiftUI.State
    private var opacity: Double = Double(Settings.translucentControllerSkinOpacity)

    private var snappedOpacity: Double {
        (opacity / 0.05).rounded() * 0.05 // 5% step
    }

    var body: some View {
        Form {
            Section {
                ForEach(System.registeredSystems, id: \.self) { system in
                    NavigationLink(destination: PreferredControllerSkinsViewController.ViewRepresentable(system: system).ignoresSafeArea()) {
                        Text(system.localizedName)
                    }
                }
            } header: {
                Text("Systems")
            } footer: {
                Text("Customize the appearance of each system. [Learn more…](https://faq.deltaemulator.com/using-delta/controller-skins)")
            }
            
            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Opacity") {
                        Text("\(Int(snappedOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $opacity, in: 0...1)
                        .onChange(of: snappedOpacity) { _, newValue in
                            Settings.translucentControllerSkinOpacity = newValue
                        }
                        .sensoryFeedback(.selection, trigger: snappedOpacity)
                }
            } footer: {
                Text("Adjusts the transparency of on-screen controller skins, if supported by the skin.")
            }
        }
        .tint(.accentColor)
        .navigationTitle("Controller Skins")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            opacity = Double(Settings.translucentControllerSkinOpacity)
        }
    }
}
