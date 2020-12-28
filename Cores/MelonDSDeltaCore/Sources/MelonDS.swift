//
//  MelonDS.swift
//  MelonDSDeltaCore
//
//  Created by Riley Testut on 10/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import DeltaCore

#if !STATIC_LIBRARY
public extension GameType
{
    static let ds = GameType("com.rileytestut.delta.game.ds")
}

public extension CheatType
{
    static let actionReplay = CheatType("ActionReplay")
}
#endif

@objc public enum MelonDSGameInput: Int, Input
{
    case a = 1
    case b = 2
    case select = 4
    case start = 8
    case right = 16
    case left = 32
    case up = 64
    case down = 128
    case r = 256
    case l = 512
    case x = 1024
    case y = 2048
    
    case touchScreenX = 4096
    case touchScreenY = 8192
    
    case lid = 16_384
    
    public var type: InputType {
        return .game(.ds)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .touchScreenX, .touchScreenY: return true
        default: return false
        }
    }
}

public struct MelonDS: DeltaCoreProtocol
{
    public static let core = MelonDS()
    
    public var name: String { "melonDS" }
    public var identifier: String { "com.rileytestut.MelonDSDeltaCore" }
    
    public var gameType: GameType { GameType.ds }
    public var gameInputType: Input.Type { MelonDSGameInput.self }
    public var gameSaveFileExtension: String { "dsv" }
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 32768, channels: 2, interleaved: true)!
    public let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 256, height: 384))
    
    public var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [actionReplayFormat]
    }
    
    public var emulatorBridge: EmulatorBridging { MelonDSEmulatorBridge.shared }
    
    private init()
    {
    }
}

// Expose DeltaCore properties to Objective-C.
public extension MelonDSEmulatorBridge
{
    @objc(dsResources) class var __dsResources: Bundle {
        return MelonDS.core.resourceBundle
    }
    
    @objc(coreDirectoryURL) class var __coreDirectoryURL: URL {
        return _coreDirectoryURL
    }
}

private let _coreDirectoryURL = MelonDS.core.directoryURL
