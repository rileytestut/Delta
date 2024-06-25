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
             description: "Customize the appearance of games when AirPlaying to your TV.")
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
    
    @Feature(name: "Skin Debugging",
             description: "Enable features useful for mapping controller skins.",
             options: SkinDebuggingOptions())
    var skinDebugging
    
    private init()
    {
        self.prepareFeatures()
    }
}

extension ExperimentalFeatures
{
    static var isExperimentalFeaturesAvailable: Bool {
        #if BETA
        // Experimental features are always available in BETA version.
        return true
        #else
        
        // Experimental features are only available for signed-in "beta access" patrons in public version.
        if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.hasBetaAccess
        {
            return true
        }
        else
        {
            return false
        }
        
        #endif
    }
}
