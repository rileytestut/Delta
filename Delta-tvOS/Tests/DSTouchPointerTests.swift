import XCTest
@testable import DeltaTVCatalog

final class DSTouchPointerTests: XCTestCase {
    func testDeadZoneDoesNotDrift() {
        var pointer = DSTouchPointer()
        for _ in 0..<60 { pointer.move(horizontal: 0.1, vertical: -0.1) }
        XCTAssertEqual(pointer.position, CGPoint(x: 0.5, y: 0.5))
    }

    func testStickDirectionsAndClamping() {
        var pointer = DSTouchPointer()
        for _ in 0..<100 { pointer.move(horizontal: 1, vertical: 1) }
        XCTAssertEqual(pointer.position, CGPoint(x: 1, y: 0))
        for _ in 0..<100 { pointer.move(horizontal: -1, vertical: -1) }
        XCTAssertEqual(pointer.position, CGPoint(x: 0, y: 1))
    }

    func testPixelZeroRemainsAnActiveTouch() {
        var pointer = DSTouchPointer()
        for _ in 0..<100 { pointer.move(horizontal: -1, vertical: 1) }
        XCTAssertGreaterThan(pointer.inputValues.x, 0)
        XCTAssertGreaterThan(pointer.inputValues.y, 0)
        XCTAssertEqual(Int(pointer.inputValues.x * 255), 0)
        XCTAssertEqual(Int(pointer.inputValues.y * 191), 0)
    }

    func testCursorUsesLowerScreen() {
        let pointer = DSTouchPointer()
        let frame = pointer.cursorFrame(in: CGSize(width: 256, height: 384))
        XCTAssertEqual(frame.midX, 128)
        XCTAssertEqual(frame.midY, 288)
    }
}
