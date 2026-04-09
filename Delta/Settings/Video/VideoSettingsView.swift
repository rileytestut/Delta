//
//  VideoSettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct VideoSettingsView: View
{
    @AppStorage(Settings.Name.supportsExternalDisplays.rawValue)
    private var supportsExternalDisplays: Bool = true
    
    @SwiftUI.State
    private var topScreenOnly: Bool = Settings.features.dsAirPlay.topScreenOnly
    
    @SwiftUI.State
    private var layoutHorizontally: Bool = Settings.features.dsAirPlay.layoutAxis == .horizontal

    var body: some View {
        Form {
            Section {
                Toggle("Support External Displays", isOn: $supportsExternalDisplays)
                    .onChange(of: supportsExternalDisplays) { _, newValue in
                        Settings.supportsExternalDisplays = newValue
                    }

                if supportsExternalDisplays
                {
                    Toggle("Top Screen Only", isOn: $topScreenOnly)
                        .onChange(of: topScreenOnly) { _, newValue in
                            Settings.features.dsAirPlay.topScreenOnly = newValue
                        }

                    if !topScreenOnly
                    {
                        Toggle("Layout Screens Horizontally", isOn: $layoutHorizontally)
                            .onChange(of: layoutHorizontally) { _, newValue in
                                Settings.features.dsAirPlay.layoutAxis = newValue ? .horizontal : .vertical
                            }
                    }
                }
            } header: {
                Text(UIDevice.current.userInterfaceIdiom == .pad ? "AirPlay / External Displays" : "AirPlay")
            } footer: {
                Text(airPlayFooter)
            }
        }
        .tint(.accentColor)
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var airPlayFooter: String {
        switch (supportsExternalDisplays, topScreenOnly, Settings.features.dsAirPlay.layoutAxis)
        {
        case (false, _, _):
            return NSLocalizedString("Games will not take over the entire display when AirPlaying.", comment: "")
            
        case (true, true, _):
            return NSLocalizedString("When AirPlaying DS games, only the top screen will appear on the external display.", comment: "")
            
        case (true, false, .vertical):
            return NSLocalizedString("When AirPlaying DS games, both screens will be stacked vertically on the external display.", comment: "")
            
        case (true, false, .horizontal):
            return NSLocalizedString("When AirPlaying DS games, both screens will be placed side-by-side on the external display.", comment: "")
        }
    }
}

#Preview {
    NavigationStack {
        VideoSettingsView()
    }
}
