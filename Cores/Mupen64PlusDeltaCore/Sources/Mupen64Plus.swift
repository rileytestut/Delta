//
//  Mupen64Plus.swift
//  Mupen64PlusDeltaCore
//
//  Created by Riley Testut on 3/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import DeltaCore

#if !STATIC_LIBRARY
public extension GameType
{
    static let n64 = GameType("com.rileytestut.delta.game.n64")
}

public extension CheatType
{
    static let gameShark = CheatType("GameShark")
}
#endif

@objc public enum Mupen64PlusGameInput: Int, Input
{
    // D-Pad
    case up = 0
    case down = 1
    case left = 2
    case right = 3
    
    // Analog-Stick
    case analogStickUp = 4
    case analogStickDown = 5
    case analogStickLeft = 6
    case analogStickRight = 7
    
    // C-Buttons
    case cUp = 8
    case cDown = 9
    case cLeft = 10
    case cRight = 11
    
    // Other
    case a = 12
    case b = 13
    case l = 14
    case r = 15
    case z = 16
    case start = 17
    
    public var type: InputType {
        return .game(.n64)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .analogStickUp, .analogStickDown, .analogStickLeft, .analogStickRight: return true
        default: return false
        }
    }
}

public struct Mupen64Plus: DeltaCoreProtocol
{
    public static let core = Mupen64Plus()
    
    public var name: String { "Mupen64Plus" }
    public var identifier: String { "com.rileytestut.N64DeltaCore" }
    
    public var gameType: GameType { GameType.n64 }
    public var gameInputType: Input.Type { Mupen64PlusGameInput.self }
    public var gameSaveFileExtension: String { "sav" }
    
    public var audioFormat: AVAudioFormat { Mupen64PlusEmulatorBridge.shared.preferredAudioFormat }
    public var videoFormat: VideoFormat { VideoFormat(format: .openGLES, dimensions: Mupen64PlusEmulatorBridge.shared.preferredVideoDimensions) }
    
    public var supportedCheatFormats: Set<CheatFormat> {
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX YYYY", type: .gameShark)
        return [gameSharkFormat]
    }
    
    public var emulatorBridge: EmulatorBridging { Mupen64PlusEmulatorBridge.shared }
    
    private init()
    {
    }
}

// Expose DeltaCore properties to Objective-C.
public extension Mupen64PlusEmulatorBridge
{
    @objc(n64Resources) class var __n64Resources: Bundle {
        return Mupen64Plus.core.resourceBundle
    }
    
    @objc(coreDirectoryURL) class var __coreDirectoryURL: URL {
        return _coreDirectoryURL
    }
}

private let _coreDirectoryURL = Mupen64Plus.core.directoryURL

