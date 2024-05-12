//
//  ServerManager+Delta.swift
//  Delta
//
//  Created by Riley Testut on 9/15/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import AltKit

extension ServerManager
{
    static let didEnableJITNotification = Notification.Name("didEnableJITNotification")
}

extension ServerManager
{
    func prepare()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(ServerManager.didChangeJITMode(_:)), name: Settings.didChangeNotification, object: nil)
        
        #if DEBUG
        if ProcessInfo.processInfo.isDebugging
        {
            // Debugger is attached at app launch, so we assume
            // we're connected to Xcode for debugging purposes.
            // In that case, we manually treat JIT as unavailable
            // until AltServer is discovered to simulate real-world use.
            ProcessInfo.isJITDisabled = true
        }
        #endif
        
        self.start()
    }
}

private extension ServerManager
{
    func start()
    {
        guard Settings.isAltJITEnabled && !ProcessInfo.processInfo.isJITAvailable else { return }
        
        self.startDiscovering()
        self.autoconnect()
    }
    
    func autoconnect()
    {
        self.autoconnect { result in
            switch result
            {
            case .failure(let error):
                print("Could not auto-connect to server.", error)
                self.autoconnect()
                
            case .success(let connection):
                func finish(result: Result<Void, Error>)
                {
                    switch result
                    {
                    case .failure(ALTServerError.unknownRequest), .failure(ALTServerError.deviceNotFound):
                        // Try connecting to a different server.
                        self.autoconnect()
                        
                    case .failure(let error):
                        print("Could not enable JIT compilation.", error)
                        
                    case .success:
                        print("Successfully enabled JIT compilation!")
                        
                        NotificationCenter.default.post(name: ServerManager.didEnableJITNotification, object: nil)
                        self.stopDiscovering()
                    }
                    
                    connection.disconnect()
                }
                
                if ProcessInfo.isJITDisabled
                {
                    ProcessInfo.isJITDisabled = false
                    finish(result: .success(()))
                }
                else
                {
                    connection.enableUnsignedCodeExecution(completion: finish)
                }
            }
        }
    }
    
    @objc func didChangeJITMode(_ notification: Notification)
    {
        guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name, name == Settings.Name.isAltJITEnabled else { return }
        
        if Settings.isAltJITEnabled
        {
            self.start()
        }
        else
        {
            self.stopDiscovering()
        }
    }
}
