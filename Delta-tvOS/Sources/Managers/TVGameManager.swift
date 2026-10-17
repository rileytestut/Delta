import Foundation
import Combine
import DeltaCore

class TVGameManager: ObservableObject {
    static let shared = TVGameManager()
    
    @Published var gamesBySystem: [TVSystem: [TVGame]] = [:]
    @Published var allGames: [TVGame] = []
    
    var romsDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let romsURL = documentsURL.appendingPathComponent("ROMs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: romsURL.path) {
            try? FileManager.default.createDirectory(at: romsURL, withIntermediateDirectories: true, attributes: nil)
        }
        return romsURL
    }
    
    init() {
        self.loadGames()
    }
    
    func loadGames() {
        var newGamesBySystem: [TVSystem: [TVGame]] = [:]
        for system in TVSystem.allCases {
            newGamesBySystem[system] = []
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoriesToScan = [self.romsDirectory, documentsURL]
        
        var scannedPaths = Set<String>()
        var flatList: [TVGame] = []
        
        for directory in directoriesToScan {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for fileURL in contents {
                guard !scannedPaths.contains(fileURL.path) else { continue }
                scannedPaths.insert(fileURL.path)
                
                let ext = fileURL.pathExtension.lowercased()
                
                for system in TVSystem.allCases {
                    if system.supportedExtensions.contains(ext) {
                        let game = TVGame(fileURL: fileURL, system: system)
                        newGamesBySystem[system]?.append(game)
                        flatList.append(game)
                        break
                    }
                }
            }
        }
        
        // Sort alphabetically by name
        for system in TVSystem.allCases {
            newGamesBySystem[system]?.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        flatList.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        DispatchQueue.main.async {
            self.gamesBySystem = newGamesBySystem
            self.allGames = flatList
        }
    }
    
    func deleteGame(_ game: TVGame) {
        try? FileManager.default.removeItem(at: game.fileURL)
        loadGames()
    }
}
