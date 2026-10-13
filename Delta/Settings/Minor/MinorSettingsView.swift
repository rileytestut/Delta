//
//  MinorSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

// Access UIDevice.isDuo
@_spi(Internal) import DeltaCore

struct MinorSettingsView: View
{
    @AppStorage(Settings.Name.isPreviewsEnabled.rawValue)
    private var isPreviewsEnabled: Bool = true

    @AppStorage(Settings.Name.pauseMenuToolbarPlacement.rawValue)
    private var pauseMenuToolbarPlacement: Settings.PauseMenuToolbarPlacement = .bottom
    
    @AppStorage(Settings.Name.showCoverSkins.rawValue)
    private var showCoverSkins: Bool = true

    var body: some View {
        Form {
            if UIDevice.current.isDuo
            {
                Section {
                    Toggle("Show Lid When Closed", isOn: $showCoverSkins)
                        .onChange(of: showCoverSkins) { _, newValue in
                            Settings.showCoverSkins = newValue
                        }
                } footer: {
                    Text("Show a lid upon closing your device, if supported by the controller skin.")
                }
            }
            
            Section {
                Toggle("Context Menu Previews", isOn: $isPreviewsEnabled)
                    .onChange(of: isPreviewsEnabled) { _, newValue in
                        Settings.isPreviewsEnabled = newValue
                    }
            } footer: {
                Text("Preview games and save states when using context menus.")
            }

            Section {
                Picker("Button Placement", selection: $pauseMenuToolbarPlacement) {
                    Text("Top").tag(Settings.PauseMenuToolbarPlacement.top)
                    Text("Bottom").tag(Settings.PauseMenuToolbarPlacement.bottom)
                }
                .onChange(of: pauseMenuToolbarPlacement) { _, newValue in
                    Settings.pauseMenuToolbarPlacement = newValue
                }
            } header: {
                Text("Pause Menu")
            } footer: {
                Text("Choose where the Resume and Home buttons appear in the pause menu.")
            }
        }
        .tint(.accentColor)
        .navigationTitle("Lil’ Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
