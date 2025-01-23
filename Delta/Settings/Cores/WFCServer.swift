//
//  WFCServer.swift
//  Delta
//
//  Created by Riley Testut on 1/16/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation

@available(iOS 15, *)
extension WFCServer
{
    static let knownServers: [WFCServer] = [
        WFCServer(name: String(localized: "Wiimmfi"), dns: "167.235.229.36", url: URL(string: "http://wiimmfi.de/")!),
        WFCServer(name: String(localized: "WiiLink WFC"), dns: "5.161.56.11", url: URL(string: "http://wfc.wiilink24.com/")!),
        WFCServer(name: String(localized: "AltWFC"), dns: "172.104.88.237", url: URL(string: "https://github.com/barronwaffles/dwc_network_server_emulator/wiki")!)
    ]
}

struct WFCServer
{
    var name: String
    var dns: String
    var url: URL
}

extension WFCServer: Identifiable
{
    var id: String { self.dns }
}
