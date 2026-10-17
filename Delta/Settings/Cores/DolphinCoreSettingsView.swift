//
//  DolphinCoreSettingsView.swift
//  Delta
//
//  Created by Riley Testut on 1/28/21.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct DolphinCoreSettingsView: CoreSettingsView
{
    var system: System { .gamecube }
    @Environment(\.openURL) var openURL
}

#Preview {
    NavigationView {
        DolphinCoreSettingsView()
    }
}
