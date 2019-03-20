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
        case gameSave = "GameSave"
        
        var localizedName: String {
            switch self
            {
            case .game: return NSLocalizedString("Game", comment: "")
            case .gameCollection: return NSLocalizedString("Game Collection", comment: "")
            case .cheat: return NSLocalizedString("Cheat", comment: "")
            case .saveState: return NSLocalizedString("Save State", comment: "")
            case .controllerSkin: return NSLocalizedString("Controller Skin", comment: "")
            case .gameControllerInputMapping: return NSLocalizedString("Game Controller Input Mapping", comment: "")
            case .gameSave: return NSLocalizedString("Game Save", comment: "")
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
    
    let syncCoordinator = SyncCoordinator(service: DriveService.shared, persistentContainer: DatabaseManager.shared)
    
    private init()
    {
        DriveService.shared.clientID = "457607414709-7oc45nq59frd7rre6okq22fafftd55g1.apps.googleusercontent.com"
        
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.syncingDidFinish(_:)), name: SyncCoordinator.didFinishSyncingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SyncManager.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension SyncManager
{
    func sync()
    {
        guard Settings.syncingService != .none else { return }
        
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
    
    @objc func didEnterBackground(_ notification: Notification)
    {
        self.sync()
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.sync()
    }
}
