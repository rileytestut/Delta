//
//  EventManager.swift
//  Delta
//
//  Created by Riley Testut on 10/7/26. Happy 31st Birthday!
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import GBADeltaCore

import Roxas

private extension URL
{
    #if STAGING
    static let events = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/events/events.json")!
    #else
    static let events = URL(string: "https://cdn.altstore.io/file/deltaemulator/events/events.json")!
    #endif
    
    #if STAGING
    
    #if BETA
    static let eventGames = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/events/games-beta.json")!
    #else
    static let eventGames = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/events/games.json")!
    #endif
    
    #else
    
    #if BETA
    static let eventGames = URL(string: "https://cdn.altstore.io/file/deltaemulator/events/games-beta.json")!
    #else
    static let eventGames = URL(string: "https://cdn.altstore.io/file/deltaemulator/events/games.json")!
    #endif
    
    #endif // STAGING
}

enum EventError: LocalizedError
{
    case unsupportedGame
    case invalidEvent
    case deltaVersionNotSupported
    
    var errorDescription: String? {
        switch self
        {
        case .unsupportedGame: return String(localized: "This game does not support DLC.")
        case .invalidEvent: return String(localized: "The DLC is invalid.")
        case .deltaVersionNotSupported: return String(localized: "This DLC requires a newer version of Delta.")
        }
    }
}

@MainActor
class EventManager
{
    static let shared = EventManager()
    
    private let deferredSession: URLSession
    
    private init()
    {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        
        self.deferredSession = URLSession(configuration: config)
    }
}

extension EventManager
{
    func updateSupportedGameIDs()
    {
        Task<Void, Never> {
            do
            {
                let (data, httpResponse) = try await self.deferredSession.data(from: .eventGames)
                if let response = httpResponse as? HTTPURLResponse
                {
                    guard response.statusCode != 404 else {
                        throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.eventGames])
                    }
                }
                
                struct Response: Decodable
                {
                    var games: [String: [String]]
                }
                
                let response = try JSONDecoder().decode(Response.self, from: data)
                for game in EventGame.allCases
                {
                    let ids = response.games[game.rawValue]
                    switch game
                    {
                    case .ruby: UserDefaults.standard.rubyEventGameIDs = ids
                    case .sapphire: UserDefaults.standard.sapphireEventGameIDs = ids
                    case .emerald: UserDefaults.standard.emeraldEventGameIDs = ids
                    case .fireRed: UserDefaults.standard.fireRedEventGameIDs = ids
                    case .leafGreen: UserDefaults.standard.leafGreenEventGameIDs = ids
                    default: break
                    }
                }
            }
            catch
            {
                Logger.main.error("Failed to update DLC supported games. \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    func fetchEvents(for game: Game) async throws -> [Event]
    {
        guard let eventGame = game.eventGame else { throw EventError.unsupportedGame }
        
        let (data, httpResponse) = try await URLSession.shared.data(from: .events)
        if let response = httpResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.events])
            }
        }
        
        struct Response: Decodable
        {
            var events: [Event]
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(Response.self, from: data)
        
        var events = response.events.filter { $0.games.contains(eventGame) }
        events = events.map { event in
            var event = event
            
            let eventBaseURL = URL.events.deletingLastPathComponent().appending(path: event.id)
            
            if event.imageURL == nil
            {
                // None specified, use default per-game URL
                let imageURL = eventBaseURL.appending(path: eventGame.rawValue + ".png")
                event.imageURL = imageURL
            }
            
            if event.patchURL == nil
            {
                // None specified, use default per-game URL
                let patchURL = eventBaseURL.appending(path: eventGame.rawValue + ".ips")
                event.patchURL = patchURL
            }
            
            return event
        }
        
        return events
    }
}

extension EventManager
{
    class func patchURL(for event: Event) throws -> URL
    {
        guard let remotePatchURL = event.patchURL else { throw EventError.invalidEvent }
        
        let eventURL = DatabaseManager.eventDirectoryURL(for: event)
        
        let patchURL = eventURL.appendingPathComponent(remotePatchURL.lastPathComponent)
        return patchURL
    }
}

extension UserDefaults
{
    @NSManaged
    var rubyEventGameIDs: [String]?
    
    @NSManaged
    var sapphireEventGameIDs: [String]?
    
    @NSManaged
    var emeraldEventGameIDs: [String]?
    
    @NSManaged
    var fireRedEventGameIDs: [String]?
    
    @NSManaged
    var leafGreenEventGameIDs: [String]?
}
