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

    static func selection(for skinIdentifier: String) -> UUID?
    {
        guard let value = ExperimentalFeatures.shared.decorativeLidCovers.selections[skinIdentifier] else { return nil }
        return UUID(uuidString: value)
    }

    static func setSelection(_ selection: UUID?, for skinIdentifier: String)
    {
        let previousSelection = self.selection(for: skinIdentifier)
        var selections = ExperimentalFeatures.shared.decorativeLidCovers.selections
        selections[skinIdentifier] = selection?.uuidString
        ExperimentalFeatures.shared.decorativeLidCovers.selections = selections

        if let identifier = previousSelection, previousSelection != selection,
           !selections.values.contains(identifier.uuidString), let url = try? self.imageURL(for: identifier)
        {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func image(for skinIdentifier: String) -> UIImage?
    {
        guard let identifier = self.selection(for: skinIdentifier), let url = try? self.imageURL(for: identifier) else { return nil }
        return UIImage(contentsOfFile: url.path)
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
        self.setSelection(identifier, for: skinIdentifier)
    }

    private static func imageURL(for identifier: UUID) throws -> URL
    {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return support.appendingPathComponent("Decorative Lid Covers", isDirectory: true).appendingPathComponent(identifier.uuidString + ".png")
    }

}
