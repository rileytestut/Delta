//
//  Keychain.swift
//  AltStore
//
//  Created by Riley Testut on 6/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import KeychainAccess

@propertyWrapper
public struct KeychainItem<Value>
{
    public let key: String
    
    public var wrappedValue: Value? {
        get {
            switch Value.self
            {
            case is Data.Type: return try? Keychain.shared.keychain.getData(self.key) as? Value
            case is String.Type: return try? Keychain.shared.keychain.getString(self.key) as? Value
            default: return nil
            }
        }
        set {
            switch Value.self
            {
            case is Data.Type: Keychain.shared.keychain[data: self.key] = newValue as? Data
            case is String.Type: Keychain.shared.keychain[self.key] = newValue as? String
            default: break
            }
        }
    }
    
    public init(key: String)
    {
        self.key = key
    }
}

public class Keychain
{
    public static let shared = Keychain()
    
    let keychain = KeychainAccess.Keychain(service: "com.rileytestut.Delta").accessibility(.afterFirstUnlock).synchronizable(true)
    
    @KeychainItem(key: "patreonAccessToken")
    public var patreonAccessToken: String?
    
    @KeychainItem(key: "patreonRefreshToken")
    public var patreonRefreshToken: String?
    
    @KeychainItem(key: "patreonCreatorAccessToken")
    public var patreonCreatorAccessToken: String?
    
    @KeychainItem(key: "patreonAccountID")
    public var patreonAccountID: String?
    
    @KeychainItem(key: "revenueCatDisplayName")
    public var revenueCatDisplayName: String?
    
    @KeychainItem(key: "revenueCatEmailAddress")
    public var revenueCatEmailAddress: String?
    
    @KeychainItem(key: "retroAchievementsUsername")
    public var retroAchievementsUsername: String?
    
    @KeychainItem(key: "retroAchievementsAuthToken")
    public var retroAchievementsAuthToken: String?
    
    private init()
    {
    }
    
    public func resetPatreon()
    {
        self.patreonAccessToken = nil
        self.patreonRefreshToken = nil
        self.patreonCreatorAccessToken = nil
        self.patreonAccountID = nil
    }
}
