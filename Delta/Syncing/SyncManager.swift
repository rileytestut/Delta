//
//  SyncManager.swift
//  Delta
//
//  Created by Riley Testut on 11/12/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Harmony
import Harmony_Drive

final class SyncManager
{
    static let shared = SyncManager()
    
    var service: Service {
        return self.syncCoordinator.service
    }
    
    var recordController: RecordController {
        return self.syncCoordinator.recordController
    }
    
    private(set) var isAuthenticated = false
    
    let syncCoordinator = SyncCoordinator(service: DriveService.shared, persistentContainer: DatabaseManager.shared)
    
    private init()
    {
        DriveService.shared.clientID = "457607414709-5puj6lcv779gpu3ql43e6k3smjj40dmu.apps.googleusercontent.com"
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
                    catch let error as AuthenticationError where error.code == .noSavedCredentials
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
