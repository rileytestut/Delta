// swiftlint:disable all
// Generated using tuist — https://github.com/tuist/tuist

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum DeltaAsset {
  public static let boxArt = DeltaImages(name: "BoxArt")
  public static let darkGray = DeltaColors(name: "DarkGray")
  public static let purple = DeltaColors(name: "Purple")
  public static let delta = DeltaImages(name: "Delta")
  public static let deltaPlaceholder = DeltaImages(name: "DeltaPlaceholder")
  public static let link = DeltaImages(name: "Link")
  public static let cheatCodes = DeltaImages(name: "CheatCodes")
  public static let fastForward = DeltaImages(name: "FastForward")
  public static let loadSaveState = DeltaImages(name: "LoadSaveState")
  public static let pause = DeltaImages(name: "Pause")
  public static let saveSaveState = DeltaImages(name: "SaveSaveState")
  public static let sustainButtons = DeltaImages(name: "SustainButtons")
  public static let settingsButton = DeltaImages(name: "SettingsButton")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public final class DeltaColors {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  public private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  fileprivate init(name: String) {
    self.name = name
  }
}

public extension DeltaColors.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: DeltaColors) {
    let bundle = DeltaResources.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

public struct DeltaImages {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = DeltaResources.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
}

public extension DeltaImages.Image {
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the DeltaImages.image property")
  convenience init?(asset: DeltaImages) {
    #if os(iOS) || os(tvOS)
    let bundle = DeltaResources.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

