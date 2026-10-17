import Foundation

enum TVImageSize: Int, CaseIterable {
    case fitScreen = 100
    case threeQuarters = 75
    case half = 50
    case third = 33
    case nativePixels = 0

    var title: String { self == .nativePixels ? "Native Pixels" : (self == .fitScreen ? "Fit Screen" : "\(rawValue)%") }
    init(savedValue: Int?) { self = savedValue.flatMap(Self.init(rawValue:)) ?? .fitScreen }

    func containerSize(screenSize: CGSize, screenScale: CGFloat, sourceSize: CGSize) -> CGSize {
        guard self == .nativePixels else {
            let factor = CGFloat(rawValue) / 100
            return CGSize(width: screenSize.width * factor, height: screenSize.height * factor)
        }
        let scale = max(1, screenScale)
        let width = max(1, sourceSize.width / scale)
        let height = max(1, sourceSize.height / scale)
        let fit = min(1, screenSize.width / width, screenSize.height / height)
        return CGSize(width: width * fit, height: height * fit)
    }
}
