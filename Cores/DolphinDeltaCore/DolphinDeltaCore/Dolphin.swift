//
//  Dolphin.swift
//  DolphinDeltaCore
//
//  Created by Riley Testut on 1/28/21.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import DeltaCore

public struct Dolphin: DeltaCoreProtocol
{
    public static let core = Dolphin()
    
    public var name: String { "Dolphin" }
    public var identifier: String { "com.rileytestut.DolphinDeltaCore" }
    
    public var gameType: GameType { GameType.gamecube }
    public var gameInputType: Input.Type { GameCubeGameInput.self }
    public var gameSaveFileExtension: String { "raw" }
    
    public var audioFormat: AVAudioFormat { DolphinEmulatorBridge.shared.preferredAudioFormat }
    public var videoFormat: VideoFormat { VideoFormat(format: .openGLES3, dimensions: DolphinEmulatorBridge.shared.preferredVideoResolution) }
    
    public var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXX-XXXX-XXXXX", type: .actionReplay)
        let geckoFormat = CheatFormat(name: NSLocalizedString("Gecko", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [actionReplayFormat, geckoFormat]
    }
    
    public var emulatorBridge: EmulatorBridging { DolphinEmulatorBridge.shared }
    
    private init()
    {
    }
}
