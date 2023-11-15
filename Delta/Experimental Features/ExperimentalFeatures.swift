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
    
    @Feature(name: "AirPlay Skins",
             description: "Customize the appearance of games when AirPlaying to your TV.",
             options: AirPlaySkinsOptions())
    var airPlaySkins
    
    @Feature(name: "Variable Fast Forward",
             description: "Change the preferred Fast Foward speed per-system. You can also change it by long-pressing the Fast Forward button from the Pause Menu.",
             options: VariableFastForwardOptions())
    var variableFastForward
    
    @Feature(name: "Show Status Bar",
             description: "Enable to show the Status Bar during gameplay.")
    var showStatusBar
    
    @Feature(name: "Game Screenshots",
             description: "When enabled, a Screenshot button will appear in the Pause Menu, allowing you to save a screenshot of your game. You can choose to save the screenshot to Photos or Files.",
             options: GameScreenshotsOptions())
    var gameScreenshots
    
    @Feature(name: "Toast Notifications",
             description: "Show toast notifications as a confirmation for various actions, such as saving your game or loading a save state.",
             options: ToastNotificationOptions())
    var toastNotifications
    
    @Feature(name: "Review Save States",
             description: "Review recent Save States to make sure they are associated with the correct game.",
             options: ReviewSaveStatesOptions())
    var reviewSaveStates
    
    @Feature(name: "Repair Database",
             description: "Repair invalid relationships in Delta's game database on next app launch.")
    var repairDatabase
    
    @Feature(name: "Alternate App Icon",
             description: "Change the app icon.",
             options: AlternateAppIconOptions())
    var alternateAppIcons
    
    private init()
    {
        self.prepareFeatures()
    }
}
