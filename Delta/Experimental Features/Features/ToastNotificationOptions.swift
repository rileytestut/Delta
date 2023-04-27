//
//  ToastNotificationOptions.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/25/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

struct ToastNotificationOptions
{
    @Option(name: "Duration", description: "Change how long toasts should be shown.", detailView: {
        let duration = $0
        HStack {
            Text("Duration: \(duration.wrappedValue, specifier: "%.1f")s")
            Slider(value: duration, in: 1...5, step: 0.5).displayInline()
        }
    })
    var duration: Double = 1.5
    
    @Option(name: "Game Data Saved",
            description: "Show toasts when performing an in game save.")
    var gameSaveEnabled: Bool = true
    
    @Option(name: "Game State Saved",
            description: "Show toasts when saving the game state.")
    var stateSaveEnabled: Bool = true
    
    @Option(name: "Game State Loaded",
            description: "Show toasts when loading the game state.")
    var stateLoadEnabled: Bool = true
    
    @Option(name: "Fast Forward Toggled",
            description: " Show toasts when toggling fast forward.")
    var fastForwardEnabled: Bool = true
}
