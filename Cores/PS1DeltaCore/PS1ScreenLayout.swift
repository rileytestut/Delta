import CoreGraphics

enum PS1ScreenLayout
{
    static func frame(in area: CGRect, sourceHeight: CGFloat, pixelsPerPoint: CGFloat, integerScale: Bool,
                      sizeStep: Int = 0, maximumArea: CGRect? = nil) -> CGRect
    {
        guard area.width > 0, area.height > 0, sourceHeight > 0, pixelsPerPoint > 0 else { return .zero }

        let fittingHeight = min(area.height, area.width * 3 / 4)
        let maximumArea = maximumArea ?? area
        let maximumHeight = min(maximumArea.height, maximumArea.width * 3 / 4)
        let multiplier = floor(fittingHeight * pixelsPerPoint / sourceHeight)
        let height: CGFloat
        if integerScale && multiplier >= 1
        {
            let maximumMultiplier = max(1, floor(maximumHeight * pixelsPerPoint / sourceHeight))
            height = sourceHeight * min(maximumMultiplier, max(1, multiplier + CGFloat(sizeStep))) / pixelsPerPoint
        }
        else
        {
            height = min(maximumHeight, fittingHeight * max(0.1, 1 + CGFloat(sizeStep) / 10))
        }
        let width = height * 4 / 3
        return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
    }

    static func offset(_ frame: CGRect, by offset: CGPoint, within bounds: CGRect) -> CGRect
    {
        let x = min(max(frame.minX + offset.x, bounds.minX), bounds.maxX - frame.width)
        let y = min(max(frame.minY + offset.y, bounds.minY), bounds.maxY - frame.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: frame.size)
    }
}
