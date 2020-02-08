///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation
import Alamofire

/// The client for the User API. Call routes using the namespaces inside this object (inherited from parent).

open class DropboxClient: DropboxBase {
    fileprivate var transportClient: DropboxTransportClient
    fileprivate var accessToken: String;
    fileprivate var selectUser: String?

    public convenience init(accessToken: String, selectUser: String? = nil, pathRoot: Common.PathRoot? = nil) {
        let transportClient = DropboxTransportClient(accessToken: accessToken, selectUser: selectUser, pathRoot: pathRoot)
        self.init(transportClient: transportClient)
    }

    public init(transportClient: DropboxTransportClient) {
        self.transportClient = transportClient
        self.selectUser = transportClient.selectUser
        self.accessToken = transportClient.accessToken
        super.init(client: transportClient)
    }

    open func withPathRoot(_ pathRoot: Common.PathRoot) -> DropboxClient {
        return DropboxClient(accessToken: self.accessToken, selectUser: self.selectUser, pathRoot: pathRoot)
    }
}
