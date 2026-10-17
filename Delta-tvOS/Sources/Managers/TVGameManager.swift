import Foundation
import Combine
import DeltaCore
import ZIPFoundation

class TVGameManager: ObservableObject {
    static let shared = TVGameManager()
    
    @Published var gamesBySystem: [TVSystem: [TVGame]] = [:]
    @Published var allGames: [TVGame] = []
    
    var romsDirectory: URL {
        // On tvOS, cachesDirectory is safe for read/write. We also support documentsDirectory.
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let romsURL = baseURL.appendingPathComponent("ROMs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: romsURL.path) {
            do {
                try FileManager.default.createDirectory(at: romsURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("[TVGameManager] Failed to create ROMs directory: \(error)")
            }
        }
        return romsURL
    }
    
    init() {
        self.loadGames()
    }
    
    func loadGames() {
        // 1. Auto-extract any ZIP files found in ROMs directory
        self.extractPendingZipFiles()
        
        var newGamesBySystem: [TVSystem: [TVGame]] = [:]
        for system in TVSystem.allCases {
            newGamesBySystem[system] = []
        }
        
        var scannedPaths = Set<String>()
        var flatList: [TVGame] = []
        
        let candidateDirs = [self.romsDirectory]
        
        for baseDir in candidateDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: baseDir,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }
                
                guard !scannedPaths.contains(fileURL.path) else { continue }
                scannedPaths.insert(fileURL.path)
                
                let ext = fileURL.pathExtension.lowercased()
                
                if let system = TVSystem.system(forFileExtension: ext) {
                    let game = TVGame(fileURL: fileURL, system: system)
                    newGamesBySystem[system]?.append(game)
                    flatList.append(game)
                }
            }
        }
        
        // Sort alphabetically
        for system in TVSystem.allCases {
            newGamesBySystem[system]?.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        flatList.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        DispatchQueue.main.async {
            self.gamesBySystem = newGamesBySystem
            self.allGames = flatList
            print("[TVGameManager] Library reloaded: \(flatList.count) games discovered.")
        }
    }
    
    func extractPendingZipFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: self.romsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return
        }
        
        for fileURL in files where fileURL.pathExtension.lowercased() == "zip" {
            print("[TVGameManager] Extracting zip file: \(fileURL.lastPathComponent)")
            do {
                try FileManager.default.unzipItem(at: fileURL, to: self.romsDirectory)
                // Remove the zip archive after successful extraction to save tvOS flash space
                try? FileManager.default.removeItem(at: fileURL)
                print("[TVGameManager] Extracted and removed: \(fileURL.lastPathComponent)")
            } catch {
                print("[TVGameManager] Failed to extract zip \(fileURL.lastPathComponent): \(error)")
            }
        }
    }
    
    func deleteGame(_ game: TVGame) {
        try? FileManager.default.removeItem(at: game.fileURL)
        loadGames()
    }
    
    func deleteFile(named filename: String) throws {
        guard filename != "data.data", !filename.hasPrefix(".") else {
            throw NSError(domain: "TVGameManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot delete system files"])
        }
        
        // Look in romsDirectory first
        let target = self.romsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
            loadGames()
            return
        }
        
        // Search in allGames
        if let match = allGames.first(where: { $0.fileURL.lastPathComponent == filename }) {
            try FileManager.default.removeItem(at: match.fileURL)
            loadGames()
            return
        }
        
        throw NSError(domain: "TVGameManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found: \(filename)"])
    }
    
    /// Returns details of all files stored in the ROMs directory for the web UI inspection
    func listAllFilesDetails() -> [[String: Any]] {
        var results: [[String: Any]] = []
        var scannedPaths = Set<String>()
        
        let candidateDirs = [self.romsDirectory]
        
        for baseDir in candidateDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: baseDir,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }
                
                guard !scannedPaths.contains(fileURL.path) else { continue }
                scannedPaths.insert(fileURL.path)
                
                let filename = fileURL.lastPathComponent
                let ext = fileURL.pathExtension.lowercased()
                
                // Skip non-game system/cache files
                let ignoredExtensions = ["plist", "savestate", "autosave", "sav", "dsv", "data", "db", "sqlite", "sqlite-wal", "sqlite-shm", "lock", "list"]
                if ignoredExtensions.contains(ext) || filename.hasPrefix(".") || filename == "data.data" {
                    continue
                }
                
                let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                let sizeBytes = Int64(resources?.fileSize ?? 0)
                let sizeFormatted = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
                
                let matchedSystem = TVSystem.system(forFileExtension: ext)

                var internalTitle = ""
                var status = "Ready to Play"
                var systemName = matchedSystem?.shortName ?? "Unknown"
                
                if let sys = matchedSystem {
                    if let title = TVGame.extractInternalROMName(fileURL: fileURL, system: sys) {
                        internalTitle = title
                    }
                } else if ext == "zip" {
                    systemName = "ZIP Archive"
                    status = "Pending Extraction"
                } else {
                    status = "Unsupported Extension"
                }
                
                results.append([
                    "filename": filename,
                    "cleanName": TVGame.cleanTitle(from: filename),
                    "internalTitle": internalTitle,
                    "system": systemName,
                    "sizeBytes": sizeBytes,
                    "sizeFormatted": sizeFormatted,
                    "status": status
                ])
            }
        }
        
        // Sort by filename
        results.sort {
            (($0["filename"] as? String) ?? "") < (($1["filename"] as? String) ?? "")
        }
        return results
    }
}
