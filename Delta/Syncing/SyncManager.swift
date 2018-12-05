//
//  SyncManager.swift
//  Delta
//
//  Created by Riley Testut on 11/12/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Harmony
import Harmony_Drive

extension SyncManager
{
    enum RecordType: String, Hashable
    {
        case game = "Game"
        case gameCollection = "GameCollection"
        case cheat = "Cheat"
        case saveState = "SaveState"
        case controllerSkin = "ControllerSkin"
        case gameControllerInputMapping = "GameControllerInputMapping"
        
        var localizedName: String {
            switch self
            {
            case .game: return NSLocalizedString("Game", comment: "")
            case .gameCollection: return NSLocalizedString("Game Collection", comment: "")
            case .cheat: return NSLocalizedString("Cheat", comment: "")
            case .saveState: return NSLocalizedString("Save State", comment: "")
            case .controllerSkin: return NSLocalizedString("Controller Skin", comment: "")
            case .gameControllerInputMapping: return NSLocalizedString("Game Controller Input Mapping", comment: "")
            }
        }
    }
}

extension Syncable where Self: NSManagedObject
{
    var recordType: SyncManager.RecordType {
        let recordType = SyncManager.RecordType(rawValue: self.syncableType)!
        return recordType
    }
}

final class SyncManager
{
    static let shared = SyncManager()
    
    var service: Service {
        return self.syncCoordinator.service
    }
    
    var recordController: RecordController {
        return self.syncCoordinator.recordController
    }
    
    private(set) var previousSyncResult: SyncResult?
    
    private(set) var isAuthenticated = false
    
    let syncCoordinator = SyncCoordinator(service: DriveService.shared, persistentContainer: DatabaseManager.shared)
    
    private init()
    {
        DriveService.shared.clientID = "457607414709-5puj6lcv779gpu3ql43e6k3smjj40dmu.apps.googleusercontent.com"
        
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.syncingDidFinish(_:)), name: SyncCoordinator.didFinishSyncingNotification, object: nil)
    }
}

extension SyncManager
{
    func start(completionHandler: @escaping (Error?) -> Void)
    {
        self.syncCoordinator.start { (result) in
            do
            {
                _ = try result.verify()
                                
                self.syncCoordinator.service.authenticateInBackground { (result) in
                    do
                    {
                        _ = try result.verify()
                        
                        self.isAuthenticated = true
                    }
                    catch let error as _AuthenticationError where error.code == .noSavedCredentials
                    {
                        // Ignore
                    }
                    catch
                    {
                        return completionHandler(error)
                    }
                    
                    completionHandler(nil)
                }
            }
            catch
            {
                completionHandler(error)
            }
        }
    }
    
    func authenticate(presentingViewController: UIViewController, completionHandler: @escaping (Error?) -> Void)
    {
        guard !self.isAuthenticated else { return completionHandler(nil) }
        
        self.service.authenticate(withPresentingViewController: presentingViewController) { (result) in
            switch result
            {
            case .success:
                self.isAuthenticated = true
                completionHandler(nil)
                
            case .failure(let error): completionHandler(error)
            }
        }
    }
    
    func sync()
    {
        guard self.isAuthenticated else { return }
        
        self.syncCoordinator.sync()
    }
}

private extension SyncManager
{
    @objc func syncingDidFinish(_ notification: Notification)
    {
        guard let result = notification.userInfo?[SyncCoordinator.syncResultKey] as? SyncResult else { return }
        self.previousSyncResult = result
    }
}
