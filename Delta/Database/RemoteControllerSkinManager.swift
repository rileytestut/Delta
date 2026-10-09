//
//  RemoteControllerSkinManager.swift
//  Delta
//
//  Created by Riley Testut on 10/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation
import CryptoKit

import DeltaCore

private extension URL
{
    #if STAGING
    static let skins = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/skins/skins.json")!
    #else
    static let skins = URL(string: "https://cdn.altstore.io/file/deltaemulator/skins/skins.json")!
    #endif
}

extension RemoteControllerSkinManager
{
    static let didUpdateControllerSkins = Notification.Name("com.rileytestut.Delta.didUpdateControllerSkins")
    
    fileprivate struct RemoteSkin: Decodable
    {
        var sha256: String
        var downloadURL: URL
    }
}

class RemoteControllerSkinManager
{
    static let shared = RemoteControllerSkinManager()
    
    private let session: URLSession
    
    private init()
    {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true // Wait until user has internet connection before trying to update skins.
        
        self.session = URLSession(configuration: config)
    }
}

extension RemoteControllerSkinManager
{
    func updateSkinsInBackground()
    {
        Task<Void, Never>(priority: .medium) {
            do
            {
                let remoteSkinsByID = try await self.fetchRemoteSkins()
                
                let context = DatabaseManager.shared.newBackgroundContext()
                let standardSkinIDs = await context.perform {
                    let predicate = NSPredicate(format: "%K == YES", #keyPath(ControllerSkin.isStandard))
                    let standardSkins = ControllerSkin.instancesWithPredicate(predicate, inManagedObjectContext: context, type: ControllerSkin.self)
                    
                    let skinIDs = standardSkins.map(\.identifier)
                    return skinIDs
                }
                
                var didUpdateSkins = false
                
                for skinID in standardSkinIDs
                {
                    // Check if a remote skin exists for this standard skin.
                    guard let remoteSkin = remoteSkinsByID[skinID] else { continue }
                    
                    do
                    {
                        // Remote skin exists, so check if we already have downloaded a remote skin for this ID.
                        let skinURL = Self.remoteSkinFileURL(forSkinID: skinID)
                        if FileManager.default.fileExists(atPath: skinURL.path)
                        {
                            do
                            {
                                let data = try Data(contentsOf: skinURL)
                                let sha256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                                guard sha256.lowercased() != remoteSkin.sha256.lowercased() else {
                                    // Hash matches already-downloaded skin, so we don't need to download it again.
                                    continue
                                }
                            }
                            catch
                            {
                                Logger.main.error("Failed to determine SHA256 hash of remote skin at \(skinURL, privacy: .public). \(error.localizedDescription, privacy: .public)")
                                
                                // Continue with downloading
                            }
                        }
                        
                        // Hash doesn't match, so download remote skin.
                        Logger.main.info("Downloading remote skin \(skinID, privacy: .public) with hash \(remoteSkin.sha256, privacy: .public) from \(remoteSkin.downloadURL, privacy: .public)...")
                        try await self.download(remoteSkin, to: skinURL)
                        Logger.main.info("Successfully updated remote skin \(skinID, privacy: .public)!")
                        
                        didUpdateSkins = true
                    }
                    catch
                    {
                        Logger.main.info("Failed to update remote skin \(skinID, privacy: .public). \(error.localizedDescription, privacy: .public)")
                    }
                }
                
                if didUpdateSkins
                {
                    NotificationCenter.default.post(name: RemoteControllerSkinManager.didUpdateControllerSkins, object: self)
                }
            }
            catch
            {
                Logger.main.error("Failed to update skins in background. \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension RemoteControllerSkinManager
{
    class func remoteSkinFileURL(forSkinID skinID: String) -> URL
    {
        let skinURL = DatabaseManager.remoteControllerSkinsDirectoryURL().appending(path: skinID + "." + "deltaskin")
        return skinURL
    }
}

private extension RemoteControllerSkinManager
{
    func fetchRemoteSkins() async throws -> [String: RemoteSkin]
    {
        let (data, httpResponse) = try await self.session.data(from: .skins)
        if let response = httpResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.skins])
            }
        }
        
        struct Response: Decodable
        {
            var skins: [String: RemoteSkin]
        }
        
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        let skins = response.skins
        return skins
    }
    
    func download(_ remoteSkin: RemoteSkin, to destinationURL: URL) async throws
    {
        let (fileURL, httpResponse) = try await self.session.download(from: remoteSkin.downloadURL)
        if let response = httpResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: remoteSkin.downloadURL])
            }
            
            guard response.statusCode < 400 else {
                throw URLError(.resourceUnavailable, userInfo: [NSURLErrorKey: remoteSkin.downloadURL])
            }
        }
        
        // Sanity check: make sure we can load this skin before copying to destinationURL.
        guard let _ = DeltaCore.ControllerSkin(fileURL: fileURL) else {
            throw URLError(.badServerResponse, userInfo: [NSURLErrorKey: remoteSkin.downloadURL])
        }
        
        try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true)
    }
}
