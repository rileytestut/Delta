//
//  WFCServer.swift
//  Delta
//
//  Created by Riley Testut on 1/16/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation

struct WFCServer: Decodable
{
    var name: String
    var dns: String
    var url: URL?
}

extension WFCServer: Identifiable
{
    var id: String { self.dns }
}

private extension WFCServer
{
    var dictionaryRepresentation: [String: Any] {
        let dictionary: [String: Any?] = [
            CodingKeys.name.stringValue: self.name,
            CodingKeys.dns.stringValue: self.dns,
            CodingKeys.url.stringValue: self.url?.absoluteString
        ]
        
        return dictionary.compactMapValues { $0 }
    }
    
    init?(dictionary: [String: Any])
    {
        guard let name = dictionary[CodingKeys.name.stringValue] as? String, let dns = dictionary[CodingKeys.dns.stringValue] as? String else { return nil }
        self.name = name
        self.dns = dns
        
        if let urlString = dictionary[CodingKeys.url.stringValue] as? String, let url = URL(string: urlString)
        {
            self.url = url
        }
    }
}

extension UserDefaults
{
    @nonobjc var wfcServers: [WFCServer]? {
        get {
            guard let servers = _wfcServers?.compactMap({ WFCServer(dictionary: $0) }) else { return nil }
            return servers
        }
        set {
            let temp = newValue?.map { $0.dictionaryRepresentation }
            _wfcServers = temp
        }
    }
    @NSManaged @objc(wfcServers) private var _wfcServers: [[String: Any]]?
}
