import Foundation
import ImageIO
import UniformTypeIdentifiers

/// File-backed decoding avoids loading a full-resolution camera image into memory.
/// Kept independent of UIKit so validation can run without an iOS Simulator runtime.
enum LidCoverImageImporter
{
    static func imageData(at url: URL) throws -> Data
    {
        let scopedAccess = url.startAccessingSecurityScopedResource()
        defer { if scopedAccess { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size <= 30 * 1024 * 1024 else { throw ImportError.tooLarge }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source),
              [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String),
              CGImageSourceGetCount(source) == 1 else { throw ImportError.invalidImage }

        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                       kCGImageSourceCreateThumbnailWithTransform: true,
                                       kCGImageSourceThumbnailMaxPixelSize: 2048,
                                       kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ImportError.invalidImage }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ImportError.invalidImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImportError.invalidImage }
        return data as Data
    }

    enum ImportError: LocalizedError
    {
        case tooLarge, invalidImage

        var errorDescription: String? {
            switch self
            {
            case .tooLarge: return String(localized: "Choose an image smaller than 30 MB.")
            case .invalidImage: return String(localized: "Choose a valid, still PNG or JPEG image.")
            }
        }
    }
}
