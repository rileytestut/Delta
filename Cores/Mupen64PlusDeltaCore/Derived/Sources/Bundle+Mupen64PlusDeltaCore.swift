// swiftlint:disable all
import Foundation

// MARK: - Swift Bundle Accessor

private class BundleFinder {}

extension Foundation.Bundle {
    /// Since Mupen64PlusDeltaCore is a framework, the bundle containing the resources is copied into the final product.
    static var module: Bundle = {
        return Bundle(for: BundleFinder.self)
    }()
}

// MARK: - Objective-C Bundle Accessor

@objc
public class Mupen64PlusDeltaCoreResources: NSObject {
   @objc public class var bundle: Bundle {
         return .module
   }
}
// swiftlint:enable all