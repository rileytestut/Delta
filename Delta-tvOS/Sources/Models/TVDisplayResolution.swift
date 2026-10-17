import Foundation

enum TVDisplayResolution: Int, CaseIterable {
    case automatic = 0
    case fullHD = 1080
    case hd = 720
    case core = 1

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .fullHD: return "1080p"
        case .hd: return "720p"
        case .core: return "Core Resolution Limit"
        }
    }

    init(savedValue: Int) { self = Self(rawValue: savedValue) ?? .automatic }

    func drawableSize(viewSize: CGSize, screenScale: CGFloat, coreSize: CGSize) -> CGSize {
        let native = CGSize(width: viewSize.width * screenScale, height: viewSize.height * screenScale)
        guard native.width > 0, native.height > 0 else { return CGSize(width: 1, height: 1) }
        let limit: CGSize
        switch self {
        case .automatic: return native
        case .fullHD: limit = CGSize(width: 1920, height: 1080)
        case .hd: limit = CGSize(width: 1280, height: 720)
        case .core: limit = coreSize
        }
        // Preserve the displayed aspect ratio and never exceed the screen's
        // own resolution. This controls display drawables, not core emulation.
        let scale = max(0, min(1, limit.width / native.width, limit.height / native.height))
        return CGSize(width: max(1, floor(native.width * scale)), height: max(1, floor(native.height * scale)))
    }
}
