//
//  Lu.swift
//  Delta
//
//  Created by Fikri Firat on 15/01/2025.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation
import DeltaFeatures

struct PlayWithLuOptions {
    // Hidden option to track if welcome message was shown
    @Option
    var didShowWelcomeMessage: Bool = false
    
    // Hidden option to track the active game being played
    @Option
    var activeGameId: String = ""
    
    // Hidden option to track the active game save state
    @Option
    var activeSaveStateId: String = ""
    
    @Option(name: "Share Gameplay Data",
            description: """
            Allow Lu to analyze gameplay data (e.g., save states, active cheats, playtime) for more personalized and accurate responses. Your personal information is never shared.
            """)
    var shareGameplayData: Bool = false
    
    @Option(name: "Remember Conversations",
            description: "Lu can save your previous questions and responses to provide context-aware advice and follow-up suggestions for each game.")
    var rememberConversations: Bool = false
}
