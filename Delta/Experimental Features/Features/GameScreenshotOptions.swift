//
//  GameScreenshotOptions.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/23/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum GameScreenshotScale: Double, CaseIterable, CustomStringConvertible
{
    case x5 = 5
    case x4 = 4
    case x3 = 3
    case x2 = 2
    
    var description: String {
        return "\(self.rawValue)x"
    }
}

extension GameScreenshotScale: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
    
    static var localizedNilDescription: Text {
        Text("Original Size")
    }
}

struct GameScreenshotOptions
{
    @Option(name: "Save to Files", description: "Save the screenshot to the app's directory in Files.")
    var saveToFiles: Bool = true
    
    @Option(name: "Save to Photos", description: "Save the screenshot to the Photo Library.")
    var saveToPhotos: Bool = false
    
    @Option(name: "Image Scale", description: "Scale up the size of the screenshot.", values: GameScreenshotScale.allCases)
    var scale: GameScreenshotScale?
}
