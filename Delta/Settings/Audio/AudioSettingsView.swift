//
//  AudioSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct AudioSettingsView: View
{
    @AppStorage(Settings.Name.respectSilentMode.rawValue)
    private var respectSilentMode: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Respect Silent Mode", isOn: $respectSilentMode)
                    .onChange(of: respectSilentMode) { _, newValue in
                        Settings.respectSilentMode = newValue
                    }
            } footer: {
                Text("When enabled, Delta will only play game audio if your device isn't silenced.")
            }
        }
        .tint(.accentColor)
        .navigationTitle("Audio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AudioSettingsView()
    }
}
