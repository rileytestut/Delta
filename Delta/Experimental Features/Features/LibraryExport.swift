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

import SDWebImage

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
    
    private struct GameInfo
    {
        var titleName: String
        var titleId: String
        var artworkURL: URL?
    }
    
    private static func exportLibrary(toCallerScheme callerScheme: String, incomingScheme: String) async
    {
        let context = DatabaseManager.shared.viewContext
        
        let gameInfos: [GameInfo] = await context.perform {
            let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.name, ascending: true)]
            
            guard let results = try? context.fetch(fetchRequest) else { return [] }
            
            return results.compactMap { game -> GameInfo? in
                // Skip BIOS pseudo-entries, which aren't real playable games.
                guard game.identifier != Game.melonDSBIOSIdentifier,
                      game.identifier != Game.melonDSDSiBIOSIdentifier
                else { return nil }
                
                return GameInfo(titleName: game.name, titleId: game.identifier, artworkURL: game.artworkURL)
            }
        }
        
        let games: [GameScheme] = gameInfos.map { info in
            GameScheme(
                titleName: info.titleName,
                titleId: info.titleId,
                developer: "",
                version: "",
                iconData: self.iconData(for: info.artworkURL)
            )
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
    
    private static func iconData(for artworkURL: URL?) -> Data?
    {
        guard let artworkURL else { return nil }
        
        let image: UIImage?
        
        if artworkURL.isFileURL
        {
            //Custom box art the user imported themselves
            image = (try? Data(contentsOf: artworkURL)).flatMap { UIImage(data: $0) }
        }
        else
        {
            //Cached Box Art from the database
            image = self.cachedImage(for: artworkURL)
        }
        
        return image?.jpegData(compressionQuality: 0.5)
    }
    
    private static func cachedImage(for url: URL) -> UIImage?
    {
        guard let manager = SDWebImageManager.shared() else { return nil }
        
        let cacheKey = manager.cacheKey(for: url)
        
        return manager.imageCache.imageFromMemoryCache(forKey: cacheKey)
            ?? manager.imageCache.imageFromDiskCache(forKey: cacheKey)
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
