import SwiftUI
import DeltaCore
import NESDeltaCore
import SNESDeltaCore
import N64DeltaCore

@main
struct DeltaTVApp: App {
    @StateObject private var gameManager = TVGameManager.shared
    @StateObject private var webServer = ROMWebServer.shared
    
    init() {
        // Register supported systems with Delta
        Delta.register(NES.core)
        Delta.register(SNES.core)
        Delta.register(N64.core)
        
        // Start monitoring physical controllers (DualSense, Xbox, Switch Pro, MFi)
        ExternalGameControllerManager.shared.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            GameLibraryView()
                .environmentObject(gameManager)
                .environmentObject(webServer)
        }
    }
}
