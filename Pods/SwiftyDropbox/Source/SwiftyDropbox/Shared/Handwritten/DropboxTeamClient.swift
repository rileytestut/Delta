///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// The client for the Business API. Call routes using the namespaces inside this object (inherited from parent).

open class DropboxTeamClient: DropboxTeamBase {
    fileprivate var transportClient: DropboxTransportClient
    fileprivate var accessToken: String

    public convenience init(accessToken: String) {
        let transportClient = DropboxTransportClient(accessToken: accessToken)
        self.init(transportClient: transportClient)
        self.accessToken = accessToken
    }

    public init(transportClient: DropboxTransportClient) {
        self.transportClient = transportClient
        self.accessToken = transportClient.accessToken
        super.init(client: transportClient)
    }

    open func asMember(_ memberId: String) -> DropboxClient {
        return DropboxClient(accessToken: self.accessToken, selectUser: memberId)
    }
}
