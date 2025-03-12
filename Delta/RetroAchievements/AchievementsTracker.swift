//
//  AchievementsTracker.swift
//  Delta
//
//  Created by Riley Testut on 3/5/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import rcheevos

extension AchievementsTracker
{
    static let didUnlockAchievementNotification = Notification.Name("DLTADidUnlockAchievementNotification")
    
    static let achievementUserInfoKey: String = "achievement"
}

final class AchievementsTracker
{
    let emulatorCore: EmulatorCore
    private let gameURL: URL
    
    private let client: OpaquePointer
    private let userData: UnsafeMutablePointer<AchievementsManager.UserData>
    
    internal init(emulatorCore: EmulatorCore, authenticatedClient: OpaquePointer) throws
    {
        self.emulatorCore = emulatorCore
        self.gameURL = emulatorCore.game.fileURL // Copy fileURL so we can reference from any thread.
        
        guard let authUserInfo = rc_client_get_user_info(authenticatedClient) else {
            throw AchievementsError(errorCode: AchievementsError.notAuthenticated, message: NSLocalizedString("User is not logged in.", comment: ""))
        }
        
        self.client = rc_client_create({ address, buffer, numberOfBytes, client in
            AchievementsManager.read(address: address, buffer: buffer, numberOfBytes: numberOfBytes, client: client)
        }, { request, callback, callbackData, client in
            AchievementsManager.send(request: request, callback: callback, callbackData: callbackData, client: client)
        })
        
        // Copy user info from authenticatedClient so we don't need to authenticate again.
        rc_client_set_user_info(self.client, authUserInfo)
        
        rc_client_enable_logging(self.client, Int32(RC_CLIENT_LOG_LEVEL_VERBOSE)) { message, client in
            AchievementsManager.log(message: message, client: client)
        }
        
        rc_client_set_event_handler(self.client) { event, client in
            AchievementsManager.handleEvent(event: event, client: client)
        }
        
        if ExperimentalFeatures.shared.retroAchievements.isHardcoreModeEnabled
        {
            rc_client_set_hardcore_enabled(self.client, 1)
        }
        
        self.userData = UnsafeMutablePointer<AchievementsManager.UserData>.allocate(capacity: 1)
        self.userData.initialize(to: AchievementsManager.UserData(tracker: self))
        rc_client_set_userdata(self.client, self.userData)
        
        let updateHandler = self.emulatorCore.updateHandler
        self.emulatorCore.updateHandler = { [weak self] emulatorCore in
            self?.didRenderFrame()
            updateHandler?(emulatorCore)
        }
    }
    
    deinit
    {
        // Must go before userData.deallocate() since userData may be referenced during the call.
        rc_client_destroy(self.client)
        
        self.userData.deallocate()
    }
}

extension AchievementsTracker
{
    func start() async throws
    {
        if self.emulatorCore.state == .stopped
        {
            // Emulator core must be started before we can load game.
            self.emulatorCore.start()
            self.emulatorCore.pause()
        }
        
        let consoleType = switch System(gameType: self.emulatorCore.deltaCore.gameType) {
        case .nes: RC_CONSOLE_NINTENDO
        case .snes: RC_CONSOLE_SUPER_NINTENDO
        case .n64: RC_CONSOLE_NINTENDO_64
        case .gbc, .gba, .ds, .genesis, nil: throw AchievementsError(errorCode: AchievementsError.unsupportedSystem, message: NSLocalizedString("System is not yet supported.", comment: ""))
        }
        
        let callback: @convention(c) (Int32, UnsafePointer<CChar>?, OpaquePointer?, UnsafeMutableRawPointer?) -> Void = { (result, errorMessage, client, userData) in
            guard let userData = userData?.assumingMemoryBound(to: AchievementsManager.UserData.self).pointee, let continuation = userData.continuation else { return }
            
            if result == RC_OK
            {
                continuation.resume()
            }
            else
            {
                let errorMessage = errorMessage.map { String(cString: $0) }
                continuation.resume(throwing: AchievementsError(errorCode: Int(result), message: errorMessage))
            }
        }
        
        let userData = UnsafeMutablePointer<AchievementsManager.UserData>.allocate(capacity: 1)
        
        try await withCheckedThrowingContinuation { continuation in
            userData.initialize(to: .init(tracker: self, continuation: continuation))
            rc_client_begin_identify_and_load_game(self.client, UInt32(consoleType), (self.gameURL as NSURL).fileSystemRepresentation, nil, 0, callback, userData)
        }
        
        userData.deallocate()
        
        if rc_client_is_processing_required(self.client) == 0
        {
            // Game has no achievements or leaderboard, so disable hardcore mode.
            rc_client_set_hardcore_enabled(self.client, 0)
        }
    }
    
    func reset()
    {
        rc_client_deserialize_progress_sized(self.client, nil, 0)
    }
}

internal extension AchievementsTracker
{
    func process(_ achievement: Achievement)
    {
        NotificationCenter.default.post(name: AchievementsTracker.didUnlockAchievementNotification, object: self, userInfo: [AchievementsTracker.achievementUserInfoKey: achievement])
    }

    func readBytes(at address: Int, into buffer: UnsafeMutablePointer<UInt8>, size: Int) -> Int
    {
        guard let data = self.emulatorCore.deltaCore.emulatorBridge.readMemory?(at: address, size: size) else { return 0 }
        
        data.withUnsafeBytes { bytes in
            _ = memcpy(buffer, bytes.baseAddress, data.count)
        }
        
        return data.count
    }
}

private extension AchievementsTracker
{
    func didRenderFrame()
    {
        rc_client_do_frame(self.client)
    }
}
