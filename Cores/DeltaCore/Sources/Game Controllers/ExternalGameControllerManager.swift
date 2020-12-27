//
//  ExternalGameControllerManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

private let ExternalKeyboardStatusDidChange: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = {
    (notificationCenter, observer, name, object, userInfo) in
    
    if ExternalGameControllerManager.shared.isKeyboardConnected
    {
        NotificationCenter.default.post(name: .externalKeyboardDidConnect, object: nil)
    }
    else
    {
        NotificationCenter.default.post(name: .externalKeyboardDidDisconnect, object: nil)
    }
}

public extension Notification.Name
{
    static let externalGameControllerDidConnect = Notification.Name("ExternalGameControllerDidConnectNotification")
    static let externalGameControllerDidDisconnect = Notification.Name("ExternalGameControllerDidDisconnectNotification")
    
    static let externalKeyboardDidConnect = Notification.Name("ExternalKeyboardDidConnect")
    static let externalKeyboardDidDisconnect = Notification.Name("ExternalKeyboardDidDisconnect")
}

public class ExternalGameControllerManager: UIResponder
{
    public static let shared = ExternalGameControllerManager()
    
    //MARK: - Properties -
    /** Properties **/
    public private(set) var connectedControllers: [GameController] = []
    
    public var automaticallyAssignsPlayerIndexes: Bool
    
    private var nextAvailablePlayerIndex: Int {
        var nextPlayerIndex = -1
        
        let sortedGameControllers = self.connectedControllers.sorted { ($0.playerIndex ?? -1) < ($1.playerIndex ?? -1) }
        for controller in sortedGameControllers
        {
            let playerIndex = controller.playerIndex ?? -1
            
            if abs(playerIndex - nextPlayerIndex) > 1
            {
                break
            }
            else
            {
                nextPlayerIndex = playerIndex
            }
        }
        
        nextPlayerIndex += 1
        
        return nextPlayerIndex
    }
    
    private override init()
    {
#if targetEnvironment(simulator)
        self.automaticallyAssignsPlayerIndexes = false
#else
        self.automaticallyAssignsPlayerIndexes = true
#endif
        
        super.init()
    }
}

//MARK: - Discovery -
/** Discovery **/
public extension ExternalGameControllerManager
{
    func startMonitoring()
    {
        for controller in GCController.controllers()
        {
            let externalController = MFiGameController(controller: controller)
            self.add(externalController)
        }
        
        if self.isKeyboardConnected
        {
            let keyboardController = KeyboardGameController()
            self.add(keyboardController)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.mfiGameControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.mfiGameControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.keyboardDidConnect(_:)), name: .externalKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.keyboardDidDisconnect(_:)), name: .externalKeyboardDidDisconnect, object: nil)
        
        if let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        {
            CFNotificationCenterAddObserver(notificationCenter, nil, ExternalKeyboardStatusDidChange, "GSEventHardwareKeyboardAttached" as CFString, nil, .deliverImmediately)
        }
    }
    
    func stopMonitoring()
    {
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: .externalKeyboardDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .externalKeyboardDidDisconnect, object: nil)
        
        self.connectedControllers.removeAll()
    }
    
    func startWirelessControllerDiscovery(withCompletionHandler completionHandler: (() -> Void)?)
    {
        GCController.startWirelessControllerDiscovery(completionHandler: completionHandler)
    }
    
    func stopWirelessControllerDiscovery()
    {
        GCController.stopWirelessControllerDiscovery()
    }
}

//MARK: - External Keyboard -
public extension ExternalGameControllerManager
{
    // Implementation based on Ian McDowell's tweet: https://twitter.com/ian_mcdowell/status/844572113759547392
    var isKeyboardConnected: Bool {
        guard let uiKeyboardClass: AnyObject = NSClassFromString("UIKeyboard") else { return false }
        
        let selector = NSSelectorFromString("shouldMinimizeForHardwareKeyboard")
        guard uiKeyboardClass.responds(to: selector) else { return false }
        
        if let _ = uiKeyboardClass.perform(selector)
        {
            // Returns non-nil value when true, so return true ourselves.
            return true
        }
        
        return false
    }
    
    override func keyPressesBegan(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for case let keyboardController as KeyboardGameController in self.connectedControllers
        {
            keyboardController.keyPressesBegan(presses, with: event)
        }
    }
    
    override func keyPressesEnded(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for case let keyboardController as KeyboardGameController in self.connectedControllers
        {
            keyboardController.keyPressesEnded(presses, with: event)
        }
    }
}

//MARK: - Managing Controllers -
private extension ExternalGameControllerManager
{
    func add(_ controller: GameController)
    {
        if self.automaticallyAssignsPlayerIndexes
        {
            let playerIndex = self.nextAvailablePlayerIndex
            controller.playerIndex = playerIndex
        }
        
        self.connectedControllers.append(controller)
        
        NotificationCenter.default.post(name: .externalGameControllerDidConnect, object: controller)
    }
    
    func remove(_ controller: GameController)
    {
        guard let index = self.connectedControllers.firstIndex(where: { $0.isEqual(controller) }) else { return }
        
        self.connectedControllers.remove(at: index)
        
        NotificationCenter.default.post(name: .externalGameControllerDidDisconnect, object: controller)
    }
}

//MARK: - MFi Game Controllers -
private extension ExternalGameControllerManager
{
    @objc func mfiGameControllerDidConnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        let externalController = MFiGameController(controller: controller)
        self.add(externalController)
    }
    
    @objc func mfiGameControllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        for externalController in self.connectedControllers
        {
            guard let mfiController = externalController as? MFiGameController else { continue }
            
            if mfiController.controller == controller
            {
                self.remove(externalController)
            }
        }
    }
}

//MARK: - Keyboard Game Controllers -
private extension ExternalGameControllerManager
{
    @objc func keyboardDidConnect(_ notification: Notification)
    {
        guard !self.connectedControllers.contains(where: { $0 is KeyboardGameController }) else { return }
        
        let keyboardController = KeyboardGameController()
        self.add(keyboardController)
    }
    
    @objc func keyboardDidDisconnect(_ notification: Notification)
    {
        guard let keyboardController = self.connectedControllers.first(where: { $0 is KeyboardGameController }) else { return }
        
        self.remove(keyboardController)
    }
}
