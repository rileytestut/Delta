//
//  SkinDebugging.swift
//  Delta
//
//  Created by Riley Testut on 6/19/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import DeltaFeatures

struct SkinDebuggingOptions
{
    @Option(name: "Show Hit Targets", description: "Show visual overlays on controller skins to represent hit targets.")
    var showHitTargets: Bool = true

    @Option(name: "Ignore Padding", description: "Ignore additional padding (“extended edges”) specified by the skin. Useful for verifying hit targets line up with controls.")
    var ignoreExtendedEdges: Bool = false
}
