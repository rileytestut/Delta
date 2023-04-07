//
//  VariableFastForward.swift
//  Delta
//
//  Created by Riley Testut on 4/5/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import Foundation
import SwiftUI

enum FastForwardSpeed: String, CaseIterable, Identifiable, CustomStringConvertible
{
    case x2 = "2x"
    case x3 = "3x"
    case x4 = "4x"
    
    var id: Self { self }
    
    var description: String {
        return self.rawValue
    }
}

class VariableFastForwardOptions: ObservableObject
{
    @Option(name: "Speed", detailView: { FastForwardSpeedView(speed: $0) })
    var value: FastForwardSpeed = .x2
}

private struct FastForwardSpeedView: View
{
    @Binding
    var speed: FastForwardSpeed

    var body: some View {
        Picker("Fast Forward Speed", selection: $speed.animation()) {
            ForEach(FastForwardSpeed.allCases) { speed in
                Text(speed.rawValue)
            }
        }
        .pickerStyle(.inline)
    }
}
