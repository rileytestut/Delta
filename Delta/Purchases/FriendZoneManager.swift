//
//  FriendZoneManager.swift
//  Delta
//
//  Created by Riley Testut on 11/12/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

private extension URL
{
    #if STAGING
    static let patreonInfo = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/delta/patreon.json")!
    #else
    static let patreonInfo = URL(string: "https://cdn.altstore.io/file/deltaemulator/delta/patreon.json")!
    #endif
}

extension FriendZoneManager
{
    static let didUpdatePatronsNotification = Notification.Name("com.rileytestut.Delta.didUpdateFriendZonePatrons")
    
    private struct Response: Decodable
    {
        var version: Int
        var accessToken: String
        var refreshID: String
        
        var disableExternalPurchaseLink: Bool?
    }
}

class FriendZoneManager
{
    static let shared = FriendZoneManager()
    
    private(set) var updatePatronsResult: Result<Void, Error>?
    
    private var updatePatronsTask: Task<Void, Never>?
}

@available(iOS 17.5, *)
extension FriendZoneManager
{
    func updatePatronsIfNeeded()
    {
        guard self.updatePatronsTask == nil else { return }
        
        self.updatePatronsResult = nil
        self.updatePatronsTask = Task { [weak self] in
            do
            {
                try await self?.updatePatrons()
                self?.updatePatronsResult = .success(())
            }
            catch
            {
                Logger.main.error("Failed to update Friend Zone patrons. \(error.localizedDescription, privacy: .public)")
                self?.updatePatronsResult = .failure(error)
            }
            
            self?.updatePatronsTask = nil
            NotificationCenter.default.post(name: FriendZoneManager.didUpdatePatronsNotification, object: self)
        }
    }
    
    func updateRevenueCatPatrons() async throws
    {
        let context = DatabaseManager.shared.newBackgroundContext()
        _ = try await self.fetchRevenueCatPatrons(in: context)
        
        try await context.perform(schedule: .enqueued) {
            try context.save()
        }
        
        NotificationCenter.default.post(name: FriendZoneManager.didUpdatePatronsNotification, object: self)
    }
}

@available(iOS 17.5, *)
private extension FriendZoneManager
{
    func updatePatrons() async throws
    {
        let (data, urlResponse) = try await URLSession.shared.data(from: .patreonInfo)
        
        if let response = urlResponse as? HTTPURLResponse
        {
            guard response.statusCode != 404 else {
                throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.patreonInfo])
            }
        }
                
        let response = try JSONDecoder().decode(Response.self, from: data)
        Keychain.shared.patreonCreatorAccessToken = response.accessToken
        
        let disableExternalPurchaseLink = response.disableExternalPurchaseLink ?? false
        UserDefaults.standard.isExternalPurchaseLinkDisabled = disableExternalPurchaseLink
        
        let previousRefreshID = UserDefaults.standard.patronsRefreshID
        guard response.refreshID != previousRefreshID && UserDefaults.standard.shouldFetchFriendZonePatrons else {
            return
        }
        
        let context = DatabaseManager.shared.newBackgroundContext()
        
        async let patreonPatrons = self.fetchPatreonPatrons(in: context)
        async let revenueCatPatrons = self.fetchRevenueCatPatrons(in: context)
        
        let allPatrons = try await revenueCatPatrons + patreonPatrons
        
        try await context.perform {
            let patronIDs = allPatrons.map(\.identifier)
            let nonFriendZonePredicate = NSPredicate(format: "NOT (%K IN %@)", #keyPath(ManagedPatron.identifier), patronIDs)
            
            let nonFriendZonePatrons = ManagedPatron.instancesWithPredicate(nonFriendZonePredicate, inManagedObjectContext: context, type: ManagedPatron.self)
            for managedPatron in nonFriendZonePatrons
            {
                context.delete(managedPatron)
            }
            
            try context.save()
        }
        
        UserDefaults.standard.patronsRefreshID = response.refreshID
        UserDefaults.standard.shouldFetchFriendZonePatrons = false // Disable fetching friend zone patrons until user navigates to Patreon screen again.
                
        Logger.main.notice("Updated all Friend Zone patrons! Refresh ID: \(response.refreshID, privacy: .public)")
    }
    
    func fetchPatreonPatrons(in context: NSManagedObjectContext) async throws -> [ManagedPatron]
    {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ManagedPatron], Error>) in
            PatreonAPI.shared.fetchPatrons { (result) in
                context.perform {
                    do
                    {
                        let patrons = try result.get()
                        
                        let managedPatrons = patrons.compactMap { ManagedPatron(name: $0.name, identifier: $0.identifier, isPatreonPatron: true, context: context) }
                        continuation.resume(returning: managedPatrons)
                    }
                    catch let error as NSError
                    {
                        Logger.main.error("Failed to update Patreon Friend Zone patrons. \(error.localizedDescription, privacy: .public)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func fetchRevenueCatPatrons(in context: NSManagedObjectContext) async throws -> [ManagedPatron]
    {
        do
        {
            let users = try await RevenueCatManager.shared.fetchFriendZoneUsers()
            
            let managedPatrons = await context.perform {
                return users.compactMap { ManagedPatron(name: $0.name, identifier: $0.id, isPatreonPatron: false, context: context) }
            }
            
            return managedPatrons
        }
        catch
        {
            Logger.main.error("Failed to update RevenueCat Friend Zone patrons. \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
