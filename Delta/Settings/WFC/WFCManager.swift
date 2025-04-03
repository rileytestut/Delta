//
//  WFCManager.swift
//  Delta
//
//  Created by Riley Testut on 2/21/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation
import MelonDSDeltaCore

private extension URL
{
#if STAGING
static let wfcServers = URL(string: "https://f000.backblazeb2.com/file/deltaemulator-staging/delta/wfc-servers.json")!
#else
static let wfcServers = URL(string: "https://cdn.altstore.io/file/deltaemulator/delta/wfc-servers.json")!
#endif
}

extension WFCManager
{
    private struct Response: Decodable
    {
        var version: Int
        var popular: [WFCServer]?
    }
}

class WFCManager
{
    static let shared = WFCManager()
    
    private let session: URLSession
    
    private var updateKnownWFCServersTask: Task<[WFCServer]?, Error>?
    
    private init()
    {
        let configuration = URLSessionConfiguration.default
        
        #if DEBUG
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        #endif
        
        self.session = URLSession(configuration: configuration)
    }
    
    @discardableResult
    func updateKnownWFCServers() -> Task<[WFCServer]?, Error>
    {
        if let task = self.updateKnownWFCServersTask
        {
            return task
        }
        
        let task = Task { [weak self] () -> [WFCServer]? in
            defer {
                self?.updateKnownWFCServersTask = nil
            }
            
            guard let self else { return nil }
            
            do
            {
                
                let (data, urlResponse) = try await self.session.data(from: .wfcServers)
                
                if let response = urlResponse as? HTTPURLResponse
                {
                    switch response.statusCode
                    {
                    case 200...299: break // OK
                    case 404: throw URLError(.fileDoesNotExist, userInfo: [NSURLErrorKey: URL.wfcServers])
                    default: throw URLError(.badServerResponse, userInfo: [NSURLErrorKey: URL.wfcServers])
                    }
                }
                
                let response = try JSONDecoder().decode(Response.self, from: data)
                UserDefaults.standard.wfcServers = response.popular
                return response.popular
            }
            catch
            {
                Logger.main.error("Failed to update known WFC servers. \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        
        self.updateKnownWFCServersTask = task
        return task
    }
    
    func resetWFCConfiguration()
    {
        Settings.preferredWFCServer = nil
        Settings.customWFCServer = nil
        
        UserDefaults.standard.removeObject(forKey: MelonDS.wfcIDUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: MelonDS.wfcFlagsUserDefaultsKey)
        
        UserDefaults.standard.didShowChooseWFCServerAlert = false
    }
}
