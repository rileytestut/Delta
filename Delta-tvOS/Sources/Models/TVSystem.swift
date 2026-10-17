import Foundation

enum TVSystem: String, CaseIterable, Identifiable {
    case nes = "NES"
    case snes = "SNES"
    case n64 = "N64"
    case gbc = "GB/GBC"
    case gba = "GBA"
    case genesis = "Mega Drive"
    case ds = "DS"
    
    var id: String { rawValue }
    
    var fullName: String {
        switch self {
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .n64: return "Nintendo 64"
        case .gbc: return "Game Boy / Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .genesis: return "Sega Mega Drive / Genesis"
        case .ds: return "Nintendo DS"
        }
    }
    
    var shortName: String {
        return rawValue
    }
    

    

    static func system(forFileExtension fileExtension: String) -> TVSystem? {
        allCases.first { $0.supportedExtensions.contains(fileExtension.lowercased()) }
    }

    static var uploadExtensions: [String] {
        Array(Set(allCases.flatMap(\.supportedExtensions) + ["zip", "png", "jpg", "jpeg"])).sorted()
    }

    var supportedExtensions: [String] {
        switch self {
        case .nes: return ["nes"]
        case .snes: return ["smc", "sfc", "fig"]
        case .n64: return ["n64", "z64", "v64"]
        case .gbc: return ["gb", "gbc"]
        case .gba: return ["gba"]
        case .genesis: return ["gen", "md", "smd", "bin"]
        case .ds: return ["ds", "nds"]
        }
    }
    
    var systemIconName: String {
        switch self {
        case .nes: return "dpad"
        case .snes: return "gamecontroller"
        case .n64: return "arcade.stick.console"
        case .gbc, .gba: return "gamecontroller"
        case .genesis: return "dpad"
        case .ds: return "rectangle.split.1x2"
        }
    }
}
