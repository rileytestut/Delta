import UIKit

import DeltaCore
import MelonDSDeltaCore
import DeltaFeatures

struct DecorativeLidCoversOptions
{
    @Option
    var selections: [String: String] = [:]
}

/// Selection metadata uses @Option; imported image bytes stay in Application Support.
/// Filenames are generated UUIDs, so imported filenames and skin identifiers never become paths.
enum LidCoverStore
{
    static var isEnabled: Bool {
        ExperimentalFeatures.shared.decorativeLidCovers.isEnabled
    }

    static func selection(for skinIdentifier: String) -> LidCoverSelection?
    {
        guard let value = ExperimentalFeatures.shared.decorativeLidCovers.selections[skinIdentifier] else { return nil }
        return LidCoverSelection(storedValue: value)
    }

    static func setSelection(_ selection: LidCoverSelection?, for skinIdentifier: String)
    {
        let previousSelection = self.selection(for: skinIdentifier)
        var selections = ExperimentalFeatures.shared.decorativeLidCovers.selections
        selections[skinIdentifier] = selection?.storedValue
        ExperimentalFeatures.shared.decorativeLidCovers.selections = selections

        if case .imported(let identifier) = previousSelection, previousSelection != selection,
           !selections.values.contains(identifier.uuidString), let url = try? self.imageURL(for: identifier)
        {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func image(for skinIdentifier: String, isCharging: Bool) -> UIImage?
    {
        if let selection = self.selection(for: skinIdentifier), let image = self.image(for: selection, isCharging: isCharging)
        {
            return image
        }

        // Missing/corrupt imports fall back without preventing a user from resetting their choice.
        guard let style = LidCoverStyle.matching(skinIdentifier: skinIdentifier) else { return nil }
        return self.image(for: .builtIn(style), isCharging: isCharging)
    }

    static func image(for selection: LidCoverSelection, isCharging: Bool) -> UIImage?
    {
        switch selection
        {
        case .builtIn(let style):
            return UIImage(named: style.assetName + (isCharging ? "-Charging" : ""))

        case .imported(let identifier):
            guard let url = try? self.imageURL(for: identifier) else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
    }

    static func defaultImage(for skin: any ControllerSkinProtocol, isCharging: Bool) -> UIImage?
    {
        if let style = LidCoverStyle.matching(skinIdentifier: skin.identifier)
        {
            return self.image(for: .builtIn(style), isCharging: isCharging)
        }
        return self.skinImage(for: skin, isCharging: isCharging)
    }

    static func skinImage(for skin: any ControllerSkinProtocol, isCharging: Bool) -> UIImage?
    {
        let traits = DeltaCore.ControllerSkin.Traits(device: .iphone, displayType: .cover, orientation: .landscape)
        let fallback = DeltaCore.ControllerSkin.standardControllerSkin(for: .ds)
        let coverSkin: (any ControllerSkinProtocol)? = skin.supports(traits) ? skin : fallback
        if isCharging, let image = coverSkin?.pressedImage(for: traits, preferredSize: .large)
        {
            return image
        }
        return coverSkin?.image(for: traits, preferredSize: .large)
    }

    /// Decode directly from a file-backed image source at a bounded resolution, including EXIF rotation.
    /// Only one static frame of a PNG/JPEG is accepted; cancellation never changes the saved selection.
    static func importImage(at url: URL, for skinIdentifier: String) throws
    {
        let data = try LidCoverImageImporter.imageData(at: url)

        let identifier = UUID()
        let destination = try self.imageURL(for: identifier)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        self.setSelection(.imported(identifier), for: skinIdentifier)
    }

    private static func imageURL(for identifier: UUID) throws -> URL
    {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return support.appendingPathComponent("Decorative Lid Covers", isDirectory: true).appendingPathComponent(identifier.uuidString + ".png")
    }

}
