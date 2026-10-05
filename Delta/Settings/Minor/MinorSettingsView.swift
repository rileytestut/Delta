//
//  MinorSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct MinorSettingsView: View
{
    @AppStorage(Settings.Name.isPreviewsEnabled.rawValue)
    private var isPreviewsEnabled: Bool = true

    @AppStorage(Settings.Name.pauseMenuToolbarPlacement.rawValue)
    private var pauseMenuToolbarPlacement: Settings.PauseMenuToolbarPlacement = .bottom

    var body: some View {
        Form {
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
