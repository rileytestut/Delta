///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
///

import Foundation

// The objects in this file are used by generated code and should not need to be invoked manually.

open class Route<ASerial: JSONSerializer, RSerial: JSONSerializer, ESerial: JSONSerializer> {
    public let name: String
    public let version: Int32
    public let namespace: String
    public let deprecated: Bool
    public let argSerializer: ASerial
    public let responseSerializer: RSerial
    public let errorSerializer: ESerial
    public let attrs: [String: String?]

    public init(name: String, version: Int32, namespace: String, deprecated: Bool,
                argSerializer: ASerial, responseSerializer: RSerial, errorSerializer: ESerial,
                attrs: [String: String?]) {
        self.name = name
        self.version = version
        self.namespace = namespace
        self.deprecated = deprecated
        self.argSerializer = argSerializer
        self.responseSerializer = responseSerializer
        self.errorSerializer = errorSerializer
        self.attrs = attrs
    }
}
