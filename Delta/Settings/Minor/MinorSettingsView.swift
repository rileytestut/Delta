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
    @AppStorage("isPreviewsEnabled") // Would use Settings.Name.isPreviewsEnabled.rawvalue but it doesn't exist
    private var isPreviewsEnabled: Bool = true

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
        }
        .tint(.accentColor)
        .navigationTitle("Minor")
        .navigationBarTitleDisplayMode(.inline)
    }
}
