//
//  QuickSaveStackOptions.swift
//  Delta
//
//  Created by Cooper Knaak on 8/4/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

import DeltaFeatures

struct QuickSaveStatesOptions
{
    enum Size: Int, CaseIterable, CustomStringConvertible, OptionValue, LocalizedOptionValue {
        case two = 2
        case four = 4
        case eight = 8

        var description: String { return "\(self.rawValue)" }
    }

    @Option(name: "Stack Size", values: Size.allCases)
    var size = Size.two
}
