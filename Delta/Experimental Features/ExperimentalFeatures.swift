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
    
    @Feature(name: "Reverse Controller Skin Screens",
             description: "Dynamically reverse the order of screen inputFrames in controller skins. Can be used to “flip” between DS screens.")
    var reverseScreens
    
    @Feature(name: "Show Touches",
             description: "Visually show touches. Useful for screen recordings and tutorials.")
    var showTouches
    
    @Feature(name: "OpenGL ES 3.0",
             description: "Render Nintendo 64 games with OpenGL ES 3.0. May fix visual issues.")
    var openGLES3
    
    @Feature(name: "Metal Renderer",
             description: "Use Metal to render games instead of OpenGL ES. Does not apply to N64 games.")
    var metal
    
    @Feature(name: "Online Multiplayer (DS)",
             description: "Play Nintendo WFC-compatible DS games online with friends.",
             options: OnlineMultiplayerOptions())
    var dsOnlineMultiplayer
    
    @Feature(name: "Lu",
             description: """
             Ask Lu questions about your games to receive helpful tips, strategies, and interesting facts tailored to the games you're playing. Lu learns from your questions and preferences to provide personalized advice. We do not collect personal information, but we do collect data to maintain and improve our experience. See our Privacy Statement and Terms of Service below for more information.
             
             https://lulabs.ai/legal
             
             If you have any questions about Lu, feel free to ask us in our Discord Server!
             
             https://discord.gg/XvSysJpQrn
             """,
             options: PlayWithLuOptions())
    var Lu
    
    private init()
    {
        self.prepareFeatures()
    }
}
