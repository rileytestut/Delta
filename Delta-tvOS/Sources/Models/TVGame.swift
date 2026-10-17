import Foundation
import DeltaCore

struct TVGame: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fileURL: URL
    let system: TVSystem
    
    var deltaGame: Game {
        Game(fileURL: fileURL, type: system.gameType)
    }
    
    init(fileURL: URL, system: TVSystem) {
        self.id = UUID()
        self.fileURL = fileURL
        self.system = system
        
        let filename = fileURL.deletingPathExtension().lastPathComponent
        // Clean up common ROM release tags like (USA), [!], (E), etc. for a clean display name
        self.name = filename
    }
}
