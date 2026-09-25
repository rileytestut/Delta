import CoreGraphics

@main
struct CheckPS1Layout
{
    static func main()
    {
        let area = CGRect(x: 0, y: 0, width: 844, height: 390)
        let frame = PS1ScreenLayout.frame(in: area, sourceHeight: 240, pixelsPerPoint: 3, integerScale: true)
        assert(abs(frame.width / frame.height - 4.0 / 3.0) < 0.0001)
        assert(frame.height * 3 / 240 == 4)
        assert(area.contains(frame))

        let highResolution = PS1ScreenLayout.frame(in: area, sourceHeight: 480, pixelsPerPoint: 3, integerScale: true)
        assert(highResolution.height * 3 / 480 == 2)
        let touchArea = PS1ScreenLayout.frame(in: CGRect(x: 234, y: 0, width: 376, height: 390),
                                              sourceHeight: 240, pixelsPerPoint: 3, integerScale: true)
        assert(touchArea.minX >= 234 && touchArea.maxX <= 610)
        assert(touchArea.height * 3 / 240 == 3)
        let larger = PS1ScreenLayout.frame(in: CGRect(x: 234, y: 0, width: 376, height: 390),
                                           sourceHeight: 240, pixelsPerPoint: 3, integerScale: true,
                                           sizeStep: 1, maximumArea: area)
        assert(larger.height * 3 / 240 == 4)
        let smaller = PS1ScreenLayout.frame(in: area, sourceHeight: 240, pixelsPerPoint: 3,
                                            integerScale: true, sizeStep: -1)
        assert(smaller.height * 3 / 240 == 3)
        let moved = PS1ScreenLayout.offset(larger, by: CGPoint(x: 1000, y: -1000), within: area)
        assert(moved.maxX == area.maxX && moved.minY == area.minY)
        let narrow = PS1ScreenLayout.frame(in: CGRect(x: 0, y: 0, width: 320, height: 800),
                                           sourceHeight: 240, pixelsPerPoint: 3, integerScale: false)
        assert(narrow.width == 320 && narrow.height == 240)
    }
}
