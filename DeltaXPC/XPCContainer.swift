//
//  XPCContainer.swift
//  DeltaXPCExtension
//
//  Created by Riley Testut on 7/9/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

var allEndpoints = [UUID: NSXPCListenerEndpoint]()

@objc(MyItemProvider) @objcMembers
public class MyItemProvider: NSObject, NSSecureCoding
{
    let name: String
    let endpoint: NSXPCListenerEndpoint?
    
    let identifier: UUID
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public init(name: String, endpoint: NSXPCListenerEndpoint)
    {
        self.name = name
        self.endpoint = endpoint
        self.identifier = UUID()
        
        allEndpoints[self.identifier] = endpoint
        
        super.init()
    }
    
    public required init?(coder: NSCoder)
    {
        let name = coder.decodeObject(forKey: "name") as! String
        let identifier = coder.decodeObject(forKey: "identifier") as! UUID
        
        let endpoint = coder.decodeObject(forKey: "endpoint") as? NSXPCListenerEndpoint
        self.endpoint = endpoint ?? allEndpoints[identifier]
        
        allEndpoints[identifier] = self.endpoint
        
        self.name = name
        self.identifier = identifier
        
        super.init()
    }
    
    public func encode(with coder: NSCoder)
    {
        coder.encode(self.name, forKey: "name")
        coder.encode(self.identifier, forKey: "identifier")
        
        if let coder = coder as? NSXPCCoder
        {
            coder.encode(self.endpoint, forKey: "endpoint")
        }
    }
}

@objc(XPCContainer) @objcMembers
public class XPCContainer: NSObject, NSSecureCoding
{
    public var name: String
    public var endpoint: NSXPCListenerEndpoint?
    
    public init(name: String, endpoint: NSXPCListenerEndpoint)
    {
        self.name = name
        self.endpoint = endpoint
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public func encode(with coder: NSCoder)
    {
        coder.encode(self.name, forKey: "name")
        coder.encode(self.endpoint, forKey: "endpoint")
        
        if let coder = coder as? NSXPCCoder
        {
//            coder.encodeXPCObject(self.end, forKey: "endpoint")
        }
    }
    
    public required init?(coder: NSCoder)
    {
        guard let name = coder.decodeObject(forKey: "name") as? String else { return nil }
        let endpoint = coder.decodeObject(forKey: "endpoint") as? NSXPCListenerEndpoint
        
        self.name = name
        self.endpoint = endpoint
    }
    
    public override var description: String {
        return "XPCContainer: \(self.name)"
    }
}
