import XCTest
@testable import DeltaTVCatalog

final class ROMCatalogTests: XCTestCase {
    func testAllExistingDeltaSystemsAreAvailable() {
        XCTAssertEqual(Set(TVSystem.allCases), [.nes, .snes, .n64, .gbc, .gba, .genesis, .ds])
    }

    func testROMExtensionsAndCaseInsensitiveDetection() {
        let fixtures: [TVSystem: [String]] = [
            .nes: ["nes"], .snes: ["smc", "sfc", "fig"], .n64: ["n64", "z64", "v64"],
            .gbc: ["gb", "gbc"], .gba: ["gba"], .genesis: ["gen", "md", "smd", "bin"], .ds: ["ds", "nds"]
        ]
        for (system, extensions) in fixtures {
            for fileExtension in extensions {
                XCTAssertEqual(TVSystem.system(forFileExtension: fileExtension), system)
                XCTAssertEqual(TVSystem.system(forFileExtension: fileExtension.uppercased()), system)
            }
        }
    }

    func testWebUploadsAcceptEveryLibraryROMExtension() {
        let uploads = Set(TVSystem.uploadExtensions)
        for system in TVSystem.allCases {
            XCTAssertTrue(Set(system.supportedExtensions).isSubset(of: uploads))
        }
        XCTAssertTrue(Set(["zip", "png", "jpg", "jpeg"]).isSubset(of: uploads))
        XCTAssertEqual(uploads.count, TVSystem.uploadExtensions.count)
    }

    func testSavesArtworkAndArchivesAreNotListedAsGames() {
        for fileExtension in ["sav", "dsv", "savestate", "png", "jpg", "zip", "iso", "chd", "exe", ""] {
            XCTAssertNil(TVSystem.system(forFileExtension: fileExtension))
        }
    }

    func testExtensionsIdentifyExactlyOneSystem() {
        let extensions = TVSystem.allCases.flatMap(\.supportedExtensions)
        XCTAssertEqual(Set(extensions).count, extensions.count)
    }
}
