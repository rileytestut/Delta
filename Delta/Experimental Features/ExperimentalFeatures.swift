//
//  ExperimentalFeatures.swift
//  Delta
//
//  Created by Riley Testut on 4/6/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import DeltaFeatures

struct ExperimentalFeatures: FeatureContainer
{
    static let shared = ExperimentalFeatures()
    
    @Feature(name: "Variable Fast Forward",
             description: "Change the preferred Fast Foward speed per-system. You can also change it by long-pressing the Fast Forward button from the Pause Menu.",
             options: VariableFastForwardOptions())
    var variableFastForward
    
    @Feature(name: "Show Status Bar",
             description: "When enabled, a Status Bar button will appear in the Pause Menu, allowing you to toggle showing the status bar in-game.",
             options: ShowStatusBarOptions())
    var showStatusBar
    
    @Feature(name: "Game Screenshots",
             description: "When enabled, a Screenshot button will appear in the Pause Menu, allowing you to save a screenshot of the Game Screen to your Photos.",
             options: GameScreenshotOptions())
    var gameScreenshots
    
    private init()
    {
        self.prepareFeatures()
    }
}
