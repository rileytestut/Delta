//
//  DeltaVisionApp.swift
//  DeltaVision
//
//  Created by Riley Testut on 6/22/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

@main
struct DeltaVisionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
