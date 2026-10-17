import XCTest
@testable import DeltaTVCatalog

final class ButtonCaptureStateTests: XCTestCase {
    func testOpeningButtonMustBeReleasedBeforeCapture() {
        var capture = ButtonCaptureState<String, String>(initiallyPressed: ["a"])
        XCTAssertNil(capture.sample([("a", "A")]))
        XCTAssertNil(capture.sample([]))
        guard case .detected("A")? = capture.sample([("a", "A")]) else {
            return XCTFail("A must be detected on the next press")
        }
    }

    func testAAndBEachSaveOnReleaseExactlyOnce() {
        for button in ["A", "B"] {
            var capture = ButtonCaptureState<String, String>(initiallyPressed: [])
            guard case .detected(let detected)? = capture.sample([(button, button)]) else {
                return XCTFail("Button was not detected")
            }
            XCTAssertEqual(detected, button)
            XCTAssertNil(capture.sample([(button, button)]))
            guard case .completed(let saved)? = capture.sample([]) else {
                return XCTFail("Mapping must save on release")
            }
            XCTAssertEqual(saved, button)
            XCTAssertNil(capture.sample([]))
            XCTAssertNil(capture.sample([(button, button)]))
        }
    }

    func testOtherHeldInputsDoNotPreventSaving() {
        var capture = ButtonCaptureState<String, String>(initiallyPressed: ["stick"])
        guard case .detected("A")? = capture.sample([("stick", "Up"), ("a", "A")]) else {
            return XCTFail("A must be detected while the stick is held")
        }
        guard case .completed("A")? = capture.sample([("stick", "Up")]) else {
            return XCTFail("A must save even though the stick has not returned to neutral")
        }
    }

    func testDifferentControllersDoNotShareButtonIdentity() {
        var capture = ButtonCaptureState<String, String>(initiallyPressed: ["controller1-a"])
        guard case .detected("A")? = capture.sample([("controller1-a", "A"), ("controller2-a", "A")]) else {
            return XCTFail("A on another controller must remain assignable")
        }
        XCTAssertEqual(capture.capturedKey, "controller2-a")
    }
}
