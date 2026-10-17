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
        TVSystem.allCases.forEach { Delta.register($0.core) }
        
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
        for system in TVSystem.allCases {
            dirsToEnsure.append(system.core.directoryURL)
        }
        dirsToEnsure.append(N64.core.directoryURL.appendingPathComponent("Config", isDirectory: true))
        
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
