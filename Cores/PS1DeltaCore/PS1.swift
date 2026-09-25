import AVFoundation
import DeltaCore

extension GameType {
    static let ps1 = GameType("com.rileytestut.delta.game.ps1")
}

@objc enum PS1GameInput: Int, _Input {
    case cross = 0
    case square = 1
    case select = 2
    case start = 3
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case circle = 8
    case triangle = 9
    case l1 = 10
    case r1 = 11
    case l2 = 12
    case r2 = 13
}

extension PS1GameInput: Input {
    var type: InputType { .game(.ps1) }
}

struct PS1: DeltaCoreProtocol {
    static let core = PS1()

    var name: String { "PCSX ReARMed" }
    var identifier: String { "com.rileytestut.PS1DeltaCore" }
    var gameType: GameType { .ps1 }
    var gameSaveFileExtension: String { "mcd" }
    var gameInputType: Input.Type { PS1GameInput.self }
    var audioFormat: AVAudioFormat { AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 2, interleaved: true)! }
    var videoFormat: VideoFormat { VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 1024, height: 512)) }
    var supportedCheatFormats: Set<CheatFormat> { [] }
    var emulatorBridge: EmulatorBridging { PS1EmulatorBridge.shared }
    var resourceBundle: Bundle { .main }
}
