//
//  RemoteProcess.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import CoreServices

import DeltaCore

extension RemoteProcess
{
    enum Status
    {
        case stopped
        case running(EmulatorBridging)
        case paused
    }
    
    enum ProcessError: Swift.Error
    {
        case crashed
        case noConnection
        case xpcServiceNotFound
    }
}

class RemoteProcess: NSObject, ObservableObject
{
    var statusPublisher: AnyPublisher<RemoteProcess.Status, Error> { self.statusSubject.eraseToAnyPublisher() }
    private let statusSubject = CurrentValueSubject<RemoteProcess.Status, Error>(RemoteProcess.Status.stopped)
    
    private let listener = NSXPCListener.anonymous()
    private var remoteExtension: NSExtension?
    private var xpcConnection: NSXPCConnection?
    
    override init()
    {
        super.init()
        
        self.listener.delegate = self
    }
    
    func start()
    {
        let extensionURL = Bundle.main.builtInPlugInsURL!.appendingPathComponent("DeltaXPC.appex")
        
        NSExtension.extension(with: extensionURL) { (remoteExtension, error) in
            if let remoteExtension = remoteExtension
            {
                remoteExtension.setRequestCancellationBlock { (uuid, error) in
                    print("Operation \(uuid) cancelled:", error)
                }
                remoteExtension.setRequestInterruptionBlock { (uuid) in
                    print("Operation \(uuid) interrupted :(")
                    self.statusSubject.send(completion: .failure(ProcessError.crashed))
                }
                
                remoteExtension.setRequestCompletionBlock { (uuid, extensionItems) in
                    self.statusSubject.send(completion: .finished)
//                    guard let item = extensionItems.first as? NSExtensionItem else { return }
//                    guard let itemProvider = item.attachments?.first else { return }
//
//                    itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (response, error) in
//                        print("Response:", response)
//                    }
                }
                
                self.startXPC(to: remoteExtension)
            }
            else if let error = error
            {
                print("Error connecting to extension:", error)
                self.statusSubject.send(completion: .failure(error))
            }
        }
    }
    
    func startXPC(to remoteExtension: NSExtension)
    {
        self.listener.resume()
        
        let itemProvider = NSItemProvider(item: ["type": "start-game",
                                                 "gameType": GameType.gba,
                                                 "endpoint": MyItemProvider(name: "Riley Testut", endpoint: self.listener.endpoint)] as NSDictionary,
                                          typeIdentifier: kUTTypePropertyList as String)
        
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider]
        
        remoteExtension.beginRequest(withInputItems: [extensionItem], completion: { (uuid) in
//
//
//
//
//            guard let xpcConnection = remoteExtension._extensionServiceConnections[uuid] as? NSXPCConnection else {
//                return self.statusSubject.send(completion: .failure(ProcessError.noConnection))
//            }
//
//            let completionSelectorString = "_completeRequestReturningItems:forExtensionContextWithUUID:completion:"
//            let completionSelector = Selector(completionSelectorString)
//
//            let existingClasses = xpcConnection.exportedInterface?.classes(for: completionSelector, argumentIndex: 0, ofReply: false) as NSSet? ?? NSSet()
//            let updatedClasses = NSSet(array: existingClasses.allObjects + [XPCContainer.self])
//            xpcConnection.exportedInterface?.setClasses(updatedClasses as! Set<AnyHashable>, for: completionSelector, argumentIndex: 0, ofReply: false)
            
            let pid = remoteExtension.pid(forRequestIdentifier: uuid)
            print("Started operation:", uuid, pid)
        })
        
        self.remoteExtension = remoteExtension
    }
    
    func connect()
    {
//        self.emulatorBridge = self.xpcConnection.remoteObjectProxyWithErrorHandler { (error) in
//            print("XPC Connection Failure:", error)
//        } as? EmulatorBridging
//
//        print("Bridge:", self.emulatorBridge)
        
        if self.remoteExtension == nil
        {
            self.listener.delegate = self
            self.listener.resume()
            
            let extensionURL = Bundle.main.builtInPlugInsURL!.appendingPathComponent("DeltaXPC.appex")
            NSExtension.extension(with: extensionURL) { (remoteExtension, error) in
                if let remoteExtension = remoteExtension
                {
                    remoteExtension.setRequestCancellationBlock { (uuid, error) in
                        print("Operation \(uuid) cancelled:", error)
                    }
                    remoteExtension.setRequestInterruptionBlock { (uuid) in
                        print("Operation \(uuid) interrupted :(")
                    }
                    remoteExtension.setRequestCompletionBlock { (uuid, extensionItems) in
                        guard let item = extensionItems.first as? NSExtensionItem else { return }
                        guard let itemProvider = item.attachments?.first else { return }
                        
                        print("Completed operation \(uuid) with items:", extensionItems)
                        
                        itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (response, error) in
                            print("Response:", response)
                        }
                    }
                    
                    self.remoteExtension = remoteExtension
                    self.connect()
                }
                else
                {
                    print("Error connecting to extension:", error)
                }
            }
            
            return
        }
        
        let itemProvider = NSItemProvider(item: ["value": "input string",
                                                 "endpoint": MyItemProvider(name: "Riley Testut", endpoint: self.listener.endpoint)] as NSDictionary,
                                          typeIdentifier: kUTTypePropertyList as String)
        
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider]
        
        self.remoteExtension?.beginRequest(withInputItems: [extensionItem], completion: { (uuid) in
            if let xpcConnection = self.remoteExtension?._extensionServiceConnections[uuid] as? NSXPCConnection
            {
                let completionSelectorString = "_completeRequestReturningItems:forExtensionContextWithUUID:completion:"
                let completionSelector = Selector(completionSelectorString)
                
                let existingClasses = xpcConnection.exportedInterface?.classes(for: completionSelector, argumentIndex: 0, ofReply: false) as NSSet? ?? NSSet()
                let updatedClasses = NSSet(array: existingClasses.allObjects) as! Set<AnyHashable>
                
                xpcConnection.exportedInterface?.setClasses(updatedClasses, for: completionSelector, argumentIndex: 0, ofReply: false)
            }
            
            print("Started operation:", uuid, self.remoteExtension?.pid(forRequestIdentifier: uuid))
        })
    }
}

extension RemoteProcess: NSXPCListenerDelegate, RemoteProcessProtocol
{
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        guard self.xpcConnection == nil else { return false }
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: EmulatorBridging.self)
        newConnection.exportedInterface = NSXPCInterface(with: RemoteProcessProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.resume()
        
        self.xpcConnection = newConnection
        
        guard let remoteObject = newConnection.remoteObjectProxyWithErrorHandler({ (error) in
            self.statusSubject.send(completion: .failure(error))
        }) as? EmulatorBridging else { return false }
        
        self.statusSubject.send(.running(remoteObject))
        
        return true
    }
    
    @objc
    func testMyFunction()
    {
        print("Received test signal!")
    }
}
