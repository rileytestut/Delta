import XCTest
@testable import DeltaTVCatalog

final class ResumeAndResolutionTests: XCTestCase {
    private func withFiles(_ body: (TVGameStateFiles) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(TVGameStateFiles(romURL: directory.appendingPathComponent("Game.gba")))
    }

    func testNewGameHasNoResumePrompt() throws {
        try withFiles { XCTAssertNil($0.resumeURL) }
    }

    func testAutomaticStateTakesPriorityAndPreservesManualState() throws {
        try withFiles { files in
            try Data([1]).write(to: files.manualURL)
            XCTAssertEqual(files.resumeURL, files.manualURL)
            try files.saveAutomatic { try Data([2, 3]).write(to: $0) }
            XCTAssertEqual(files.resumeURL, files.automaticURL)
            XCTAssertEqual(try Data(contentsOf: files.manualURL), Data([1]))
            XCTAssertEqual(try Data(contentsOf: files.automaticURL), Data([2, 3]))
        }
    }

    func testFailedOrEmptySaveDoesNotReplacePreviousResumePoint() throws {
        try withFiles { files in
            try files.saveAutomatic { try Data([42]).write(to: $0) }
            XCTAssertThrowsError(try files.saveAutomatic { _ in throw CocoaError(.fileWriteUnknown) })
            XCTAssertThrowsError(try files.saveAutomatic { try Data().write(to: $0) })
            XCTAssertEqual(try Data(contentsOf: files.automaticURL), Data([42]))
            let remaining = try FileManager.default.contentsOfDirectory(atPath: files.romURL.deletingLastPathComponent().path)
            XCTAssertEqual(remaining, ["Game.gba.autosave"])
        }
    }

    func testEmptyStateIsNotOfferedForResume() throws {
        try withFiles { files in
            try Data().write(to: files.automaticURL)
            XCTAssertNil(files.resumeURL)
            try Data([1]).write(to: files.manualURL)
            XCTAssertEqual(files.resumeURL, files.manualURL)
        }
    }

    func testSameNamedROMsHaveSeparateAutomaticStates() {
        let gba = TVGameStateFiles(romURL: URL(fileURLWithPath: "/ROMs/Game.gba"))
        let gbc = TVGameStateFiles(romURL: URL(fileURLWithPath: "/ROMs/Game.gbc"))
        XCTAssertNotEqual(gba.automaticURL, gbc.automaticURL)
    }

    func test4KDrawableCanBeLimitedTo1080pAnd720p() {
        let bounds = CGSize(width: 1920, height: 1080)
        let core = CGSize(width: 640, height: 480)
        XCTAssertEqual(TVDisplayResolution.automatic.drawableSize(viewSize: bounds, screenScale: 2, coreSize: core), CGSize(width: 3840, height: 2160))
        XCTAssertEqual(TVDisplayResolution.fullHD.drawableSize(viewSize: bounds, screenScale: 2, coreSize: core), CGSize(width: 1920, height: 1080))
        XCTAssertEqual(TVDisplayResolution.hd.drawableSize(viewSize: bounds, screenScale: 2, coreSize: core), CGSize(width: 1280, height: 720))
    }

    func testCoreLimitPreservesDisplayedAspectRatio() {
        let core = CGSize(width: 640, height: 480)
        XCTAssertEqual(TVDisplayResolution.core.drawableSize(viewSize: CGSize(width: 1920, height: 1440), screenScale: 2, coreSize: core), core)
        XCTAssertEqual(TVDisplayResolution.core.drawableSize(viewSize: CGSize(width: 1920, height: 1080), screenScale: 2, coreSize: core), CGSize(width: 640, height: 360))
    }

    func testResolutionDoesNotUpscaleSmallDisplays() {
        let bounds = CGSize(width: 640, height: 480)
        XCTAssertEqual(TVDisplayResolution.fullHD.drawableSize(viewSize: bounds, screenScale: 1, coreSize: bounds), bounds)
        XCTAssertEqual(TVDisplayResolution(savedValue: -10), .automatic)
    }
}

final class ImageSizeTests: XCTestCase {
    func testNativePixelsUsesScreenScaleRatherThanAFixedPercentage() {
        let size = TVImageSize.nativePixels.containerSize(screenSize: CGSize(width: 1920, height: 1080), screenScale: 2, sourceSize: CGSize(width: 640, height: 480))
        XCTAssertEqual(size, CGSize(width: 320, height: 240))
        XCTAssertEqual(size.width * 2, 640)
        XCTAssertEqual(size.height * 2, 480)
    }

    func testImageSizesAndDefault() {
        let screen = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(TVImageSize(savedValue: nil), .fitScreen)
        XCTAssertEqual(TVImageSize(savedValue: -1), .fitScreen)
        XCTAssertEqual(TVImageSize.half.containerSize(screenSize: screen, screenScale: 2, sourceSize: .zero), CGSize(width: 960, height: 540))
        XCTAssertEqual(TVImageSize.fitScreen.containerSize(screenSize: screen, screenScale: 2, sourceSize: .zero), screen)
    }

    func testLargeNativeImageStillFitsDisplay() {
        let size = TVImageSize.nativePixels.containerSize(screenSize: CGSize(width: 800, height: 600), screenScale: 1, sourceSize: CGSize(width: 1600, height: 1200))
        XCTAssertEqual(size, CGSize(width: 800, height: 600))
    }
}
