import Foundation

var assertions = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String)
{
    precondition(condition(), message)
    assertions += 1
}

for style in LidCoverStyle.allCases
{
    for layout in ["inner-book", "cover", "split-view"]
    {
        expect(LidCoverStyle.matching(skinIdentifier: "com.duods.delta.ds.\(style.rawValue).\(layout)") == style, "Official DuoDS variant must match")
    }
    let selection = LidCoverSelection.builtIn(style)
    expect(LidCoverSelection(storedValue: selection.storedValue) == selection, "Built-in selection must survive persistence")
}
for identifier in ["", "com.duods.delta.ds.gold.cover", "com.duods.delta.ds.navy", "com.duods.delta.ds.navy.cover.extra", "custom.DuoDS.Graphite", "com.duods.delta.ds.graphite.unknown"]
{
    expect(LidCoverStyle.matching(skinIdentifier: identifier) == nil, "Unrecognized identifiers must retain the skin's own default")
}
let imported = LidCoverSelection.imported(UUID())
expect(LidCoverSelection(storedValue: imported.storedValue) == imported, "Imported selection must survive persistence")
for value in ["../../cover.png", "/tmp/cover.png", "invalid", "", "Graphite"]
{
    expect(LidCoverSelection(storedValue: value) == nil, "Invalid persisted values must be rejected")
}
let defaults = UserDefaults(suiteName: "LidCoverTests.\(UUID().uuidString)")!
let first = "com.duods.delta.ds.graphite.inner-book"
let second = "com.duods.delta.ds.navy.cover"
let values = [first: LidCoverSelection.builtIn(.snow).storedValue, second: imported.storedValue]
defaults.set(values, forKey: "selections")
expect(defaults.dictionary(forKey: "selections") as? [String: String] == values, "Per-skin selections must persist independently")
var resetValues = defaults.dictionary(forKey: "selections") as! [String: String]
resetValues[first] = nil
expect(resetValues[second] == imported.storedValue, "Reset must leave other skins' selections alone")
defaults.removeObject(forKey: "selections")

// Exercise the production ImageIO importer on macOS; no simulator or UIKit mocks required.
import ImageIO
import UniformTypeIdentifiers

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LidCoverImportTests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
func fixture(_ name: String, type: UTType, width: Int = 80, height: Int = 40, orientation: Int = 1) throws -> URL
{
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let url = directory.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    expect(CGImageDestinationFinalize(destination), "Fixture should encode")
    return url
}
func decoded(_ data: Data) -> CGImage
{
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    expect(CGImageSourceGetType(source)! as String == UTType.png.identifier, "Imports normalize to PNG")
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
for type in [UTType.png, .jpeg]
{
    let url = try fixture("valid.\(type.preferredFilenameExtension!)", type: type)
    let image = decoded(try LidCoverImageImporter.imageData(at: url))
    expect(image.width == 80 && image.height == 40, "Valid PNG/JPEG dimensions should survive import")
}
let largeURL = try fixture("large.png", type: .png, width: 4096, height: 2048)
let largeImage = decoded(try LidCoverImageImporter.imageData(at: largeURL))
expect(largeImage.width == 2048 && largeImage.height == 1024, "Large images must be downsampled proportionally")
let rotatedURL = try fixture("rotated.jpg", type: .jpeg, orientation: 6)
let rotated = decoded(try LidCoverImageImporter.imageData(at: rotatedURL))
expect(rotated.width == 40 && rotated.height == 80, "EXIF orientation must be applied before persisting")
let corrupt = directory.appendingPathComponent("corrupt.png")
try Data("not an image".utf8).write(to: corrupt)
let gif = try fixture("unsupported.gif", type: .gif)
for url in [corrupt, gif]
{
    do
    {
        _ = try LidCoverImageImporter.imageData(at: url)
        fatalError("Corrupt and unsupported files must be rejected")
    }
    catch LidCoverImageImporter.ImportError.invalidImage { assertions += 1 }
}
let oversized = directory.appendingPathComponent("oversized.png")
FileManager.default.createFile(atPath: oversized.path, contents: nil)
let handle = try FileHandle(forWritingTo: oversized)
try handle.truncate(atOffset: 31 * 1024 * 1024)
try handle.close()
do
{
    _ = try LidCoverImageImporter.imageData(at: oversized)
    fatalError("Oversized files must be rejected before decoding")
}
catch LidCoverImageImporter.ImportError.tooLarge { assertions += 1 }
print("Passed \(assertions) model and image-import assertions")
