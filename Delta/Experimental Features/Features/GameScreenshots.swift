//
//  GameScreenshots.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/24/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaFeatures

enum ScreenshotSize: Double, CaseIterable, CustomStringConvertible
{
    case x5 = 5
    case x4 = 4
    case x3 = 3
    case x2 = 2
    
    var description: String {
        if #available(iOS 15, *)
        {
            let formattedText = self.rawValue.formatted(.number.decimalSeparator(strategy: .automatic))
            return "\(formattedText)x Size"
        }
        else
        {
            return "\(self.rawValue)x Size"
        }
    }
}

extension ScreenshotSize: LocalizedOptionValue
{
    var localizedDescription: Text {
        Text(self.description)
    }
    
    static var localizedNilDescription: Text {
        Text("Original Size")
    }
}

struct GameScreenshotsOptions
{
    @Option(name: "Save to Files", description: "Save the screenshot to the app's directory in Files.")
    var saveToFiles: Bool = true

    @Option(name: "Save to Photos", description: "Save the screenshot to the Photo Library.")
    var saveToPhotos: Bool = false

    @Option(name: "Image Size", description: "Choose the size of screenshots. This only increases the export size, it does not increase the quality.", values: ScreenshotSize.allCases)
    var size: ScreenshotSize?
}
