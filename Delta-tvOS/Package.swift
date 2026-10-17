// swift-tools-version: 5.9
import PackageDescription

// Platform-independent tests use the same ROM catalog as the tvOS application.
let package = Package(
    name: "DeltaTVCatalog",
    products: [.library(name: "DeltaTVCatalog", targets: ["DeltaTVCatalog"])],
    targets: [
        .target(name: "DeltaTVCatalog", path: "Sources/Models",
                exclude: ["TVGame.swift", "TVSystem+DeltaCore.swift"], sources: ["TVSystem.swift", "DSTouchPointer.swift", "ButtonCaptureState.swift", "TVGameStateFiles.swift", "TVDisplayResolution.swift", "TVImageSize.swift"]),
        .testTarget(name: "DeltaTVCatalogTests", dependencies: ["DeltaTVCatalog"], path: "Tests")
    ]
)
