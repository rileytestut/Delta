//
//  FastForwardSpeedPicker.swift
//  Delta
//
//  Created by Adam Grushan on 7/3/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import DeltaFeatures

struct FastForwardSpeedPickerOptions
{
    // "Picker" option, appears as a standard inline picker in Delta's settings.
    //
    // Reuses the FastForwardSpeed type declared in VariableFastForward.swift, which already
    // conforms to LocalizedOptionValue (displaying e.g. "3x") and persists as its Double rawValue.
    //
    // The option is Optional, so Delta automatically adds a `nil` choice to the picker,
    // displayed as "Maximum" via FastForwardSpeed.localizedNilDescription. Choosing it
    // falls back to each system's maximum supported speed (Delta's default behavior).
    @Option(name: "Speed",
            description: "This speed applies to all systems. Speeds above a system’s maximum supported speed are capped at that maximum.",
            values: [2.0, 3.0, 4.0, 8.0].map { FastForwardSpeed(rawValue: $0) })
    var speed: FastForwardSpeed?
}

extension GameViewController
{
    /// The fast forward speed chosen via the "Fast Forward Speed Picker" experimental feature,
    /// capped at the current system's maximum supported speed.
    ///
    /// Returns `nil` — and therefore has no effect on the rest of the app — when:
    /// * the feature is disabled,
    /// * no speed has been picked (i.e. "Maximum" is selected), or
    /// * there is no active emulator core.
    var experimentalPickedFastForwardSpeed: Double? {
        // All behavior changes are locked behind the feature's isEnabled runtime check.
        guard ExperimentalFeatures.shared.fastForwardSpeedPicker.isEnabled else { return nil }

        guard let emulatorCore = self.emulatorCore, let speed = ExperimentalFeatures.shared.fastForwardSpeedPicker.speed else { return nil }

        // Cap the picked speed at the system's maximum supported rate so one global
        // setting can safely apply to every system (e.g. 8x is capped for systems that only support 4x).
        return min(speed.rawValue, emulatorCore.deltaCore.supportedRates.upperBound)
    }
}
