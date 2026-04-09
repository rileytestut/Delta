//
//  CoresListView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct CoresListView: View
{
    var body: some View {
        Form {
            ForEach(System.registeredSystems, id: \.self) { system in
                NavigationLink(destination: coreSettingsDestination(for: system)) {
                    LabeledContent(system.localizedName) {
                        Text(coreName(for: system))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.accentColor)
        .navigationTitle("Cores")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func coreName(for system: System) -> String
    {
        if system == .ds
        {
            let core = Settings.preferredCore(for: .ds)
            return core?.metadata?.name.value ?? core?.name ?? NSLocalizedString("Unknown", comment: "")
        }
        else
        {
            return system.deltaCore.name
        }
    }
    
    @ViewBuilder
    private func coreSettingsDestination(for system: System) -> some View
    {
        switch system
        {
        case .nes: NESCoreSettingsView()
        case .genesis: GenesisCoreSettingsView()
        case .snes: SNESCoreSettingsView()
        case .n64: N64CoreSettingsView()
        case .gbc: GBCCoreSettingsView()
        case .gba: GBACoreSettingsView()
        case .ds: MelonDSCoreSettingsView()
        }
    }
}
