import Foundation

/// Normalized coordinates within the lower DS screen, independent of display size.
struct DSTouchPointer {
    private(set) var position = CGPoint(x: 0.5, y: 0.5)

    mutating func move(horizontal: Float, vertical: Float) {
        func delta(_ value: Float) -> CGFloat {
            abs(value) > 0.15 ? CGFloat(value) * 0.015 : 0
        }
        position.x = min(1, max(0, position.x + delta(horizontal)))
        position.y = min(1, max(0, position.y - delta(vertical)))
    }

    var inputValues: (x: Double, y: Double) {
        // EmulatorCore treats zero as release. The smallest positive coordinate
        // still rounds to pixel zero in melonDS while keeping the stylus down.
        (max(0.000001, Double(position.x)), max(0.000001, Double(position.y)))
    }

    func cursorFrame(in size: CGSize) -> CGRect {
        let centerX: CGFloat = position.x * size.width
        let centerY: CGFloat = (1 + position.y) * (size.height / 2)
        return CGRect(origin: CGPoint(x: centerX - 9, y: centerY - 9), size: CGSize(width: 18, height: 18))
    }
}
