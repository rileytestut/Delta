//
//  LibraryExport.swift
//  Delta
//
//  Adds support for exporting the user's game library to other apps
//  via a custom URL scheme.
//
//  Incoming URL:  delta://gameInfo?scheme=<callerScheme>
//  Callback URL: <callerScheme>://delta?games=<base64urlEncodedJSON>
//

import UIKit
import CoreData

import DeltaCore

enum LibraryExport
{
    static let host = "gameInfo"
    
    struct GameScheme: Codable, Identifiable, Equatable, Hashable, Sendable
    {
        var id = UUID().uuidString
        var titleName: String
        var titleId: String
        var developer: String
        var version: String
        var iconData: Data?
    }
    
    @MainActor
    @discardableResult
    static func handle(_ url: URL) -> Bool
    {
        guard ExperimentalFeatures.shared.libraryExport.isEnabled else { return false }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host?.lowercased() == self.host.lowercased()
        else { return false }
        
        guard let callerScheme = components.queryItems?.first(where: { $0.name == "scheme" })?.value,
              !callerScheme.isEmpty
        else {
            Logger.main.error("Library export request is missing required `scheme` query parameter.")
            return false
        }
        
        let incomingScheme = url.scheme ?? "delta"
        
        Task {
            await self.exportLibrary(toCallerScheme: callerScheme, incomingScheme: incomingScheme)
        }
        
        return true
    }
    
    private static func exportLibrary(toCallerScheme callerScheme: String, incomingScheme: String) async
    {
        let context = DatabaseManager.shared.viewContext
        
        let games: [GameScheme] = await context.perform {
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.name, ascending: true)]
            
            guard let results = try? context.fetch(fetchRequest) else { return [] }
            
            return results.compactMap { game -> GameScheme? in
                // Skip BIOS pseudo-entries, which aren't real playable games.
                guard game.identifier != Game.melonDSBIOSIdentifier,
                      game.identifier != Game.melonDSDSiBIOSIdentifier
                else { return nil }
                
                return GameScheme(
                    titleName: game.name,
                    titleId: game.identifier,
                    developer: "",
                    version: "",
                    iconData: self.iconData(for: game)
                )
            }
        }
        
        guard let payload = try? JSONEncoder().encode(games) else {
            Logger.main.error("Failed to encode library export payload.")
            return
        }
        
        let encoded = payload.base64URLEncodedString()
        
        guard let returnURL = URL(string: "\(callerScheme)://\(incomingScheme)?games=\(encoded)") else {
            Logger.main.error("Failed to construct library export callback URL.")
            return
        }
        
        await UIApplication.shared.open(returnURL)
    }
    
    private static func iconData(for game: Game) -> Data?
    {
        guard let artworkURL = game.artworkURL, artworkURL.isFileURL,
              let data = try? Data(contentsOf: artworkURL),
              let image = UIImage(data: data)
        else { return nil }
        
        return image.jpegData(compressionQuality: 0.5)
    }
}

private extension Data
{
    func base64URLEncodedString() -> String
    {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
