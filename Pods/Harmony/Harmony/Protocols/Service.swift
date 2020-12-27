//
//  Service.swift
//  Harmony
//
//  Created by Riley Testut on 6/4/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

public protocol Service
{
    var localizedName: String { get }
    var identifier: String { get }
    
    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    func authenticateInBackground(completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void)
    
    func deauthenticate(completionHandler: @escaping (Result<Void, DeauthenticationError>) -> Void)
    
    func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data), FetchError>) -> Void) -> Progress
    func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>) -> Void) -> Progress
    
    func upload(_ record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void) -> Progress
    func download(_ record: AnyRecord, version: Version, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord, RecordError>) -> Void) -> Progress
    func delete(_ record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    
    func upload(_ file: File, for record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteFile, FileError>) -> Void) -> Progress
    func download(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<File, FileError>) -> Void) -> Progress
    func delete(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<Void, FileError>) -> Void) -> Progress
    
    func updateMetadata(_ metadata: [HarmonyMetadataKey: Any], for record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress
    
    func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress
}

public func ==(lhs: Service, rhs: Service) -> Bool
{
    return lhs.identifier == rhs.identifier
}

public func !=(lhs: Service, rhs: Service) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(lhs: Service, rhs: Service) -> Bool
{
    return lhs == rhs
}
