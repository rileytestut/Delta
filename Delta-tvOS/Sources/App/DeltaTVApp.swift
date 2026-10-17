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
        
        // Ensure all required system and emulator core directories exist on tvOS flash
        self.setupStorageDirectories()
    }
    
    private func setupStorageDirectories() {
        let fm = FileManager.default
        var dirsToEnsure: [URL] = []
        
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            dirsToEnsure.append(caches)
            dirsToEnsure.append(caches.appendingPathComponent("ROMs", isDirectory: true))
            dirsToEnsure.append(caches.appendingPathComponent("Mupen64Plus", isDirectory: true))
        }
        dirsToEnsure.append(Delta.coresDirectoryURL)
        dirsToEnsure.append(N64.core.directoryURL)
        dirsToEnsure.append(N64.core.directoryURL.appendingPathComponent("Config", isDirectory: true))
        dirsToEnsure.append(SNES.core.directoryURL)
        dirsToEnsure.append(NES.core.directoryURL)
        
        for dir in dirsToEnsure {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("[DeltaTVApp] Directory creation error for \(dir.path): \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            GameLibraryView()
                .environmentObject(gameManager)
                .environmentObject(webServer)
        }
    }
}
