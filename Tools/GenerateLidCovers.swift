// Run from the repository root: swift Tools/GenerateLidCovers.swift
// Original vector construction, exported to lossless PNGs for UIKit's asset catalog.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Resources/Assets.xcassets/Decorative Lids")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}\n".utf8).write(to: output.appendingPathComponent("Contents.json"))

// Colors sampled from the official DuoDS shells; shapes are constructed independently.
let palettes: [(String, String, String)] = [
    ("Graphite", "6F6F6F", "B6BCBD"),
    ("Snow", "E5E6E7", "9FA9AC"),
    ("Frost", "C1DBE8", "648CA4"),
    ("Navy", "384E73", "91AEC6"),
    ("Blossom", "EDC9D5", "AC748D")
]
func color(_ hex: String, alpha: CGFloat = 1) -> NSColor
{
    let value = UInt32(hex, radix: 16)!
    return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                   green: CGFloat((value >> 8) & 255) / 255,
                   blue: CGFloat(value & 255) / 255, alpha: alpha)
}
func rounded(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1)
{
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke
    {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}
func drawLid(name: String, shell: String, accent: String, charging: Bool)
{
    // Landscape artwork matching the standard 678:466 cover; the live cover and import preview use the same centered fill.
    let canvas = CGRect(x: 0, y: 0, width: 2048, height: 1408)
    color(shell).setFill()
    canvas.fill()
    let base = color(shell)
    let top = base.blended(withFraction: 0.16, of: .white)!
    let bottom = base.blended(withFraction: 0.12, of: .black)!
    NSGradient(starting: bottom, ending: top)!.draw(in: canvas, angle: 90)

    // Inset shell seam, highlight, and a quiet hinge rail.
    rounded(CGRect(x: 27, y: 27, width: 1994, height: 1354), radius: 80,
            fill: .clear, stroke: color("000000", alpha: 0.17), lineWidth: 3)
    rounded(CGRect(x: 31, y: 31, width: 1986, height: 1346), radius: 77,
            fill: .clear, stroke: color("FFFFFF", alpha: 0.28), lineWidth: 2)
    rounded(CGRect(x: 99, y: 65, width: 1850, height: 9), radius: 4,
            fill: color("000000", alpha: 0.13))
    rounded(CGRect(x: 121, y: 67, width: 1806, height: 2), radius: 1,
            fill: color("FFFFFF", alpha: 0.23))

    // Two offset rounded outlines recall a dual-screen handheld without using a brand logo.
    let center = CGPoint(x: 1024, y: 728)
    for (x, y) in [(center.x - 83, center.y - 27), (center.x - 23, center.y - 69)]
    {
        rounded(CGRect(x: x, y: y - 2, width: 106, height: 74), radius: 13,
                fill: .clear, stroke: color("FFFFFF", alpha: 0.38), lineWidth: 4)
        rounded(CGRect(x: x, y: y, width: 106, height: 74), radius: 13,
                fill: .clear, stroke: color(accent, alpha: 0.85), lineWidth: 4)
    }

    // Tiny original wordmark, with generous negative space around the embossed motif.
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: color(accent, alpha: 0.88),
        .kern: 7
    ]
    let label = NSAttributedString(string: "D U A L", attributes: attrs)
    label.draw(at: CGPoint(x: center.x - label.size().width / 2, y: 582))

    // Power and charge windows sit clear of the central crop's focal point.
    rounded(CGRect(x: 1776, y: 114, width: 48, height: 12), radius: 6,
            fill: color("142B25", alpha: 0.5), stroke: color("FFFFFF", alpha: 0.3))
    rounded(CGRect(x: 1841, y: 114, width: 48, height: 12), radius: 6,
            fill: charging ? color("F4AE48") : color("38342C", alpha: 0.38),
            stroke: color("FFFFFF", alpha: 0.3))
    if charging
    {
        rounded(CGRect(x: 1846, y: 117, width: 38, height: 6), radius: 3, fill: color("FFE3A8"))
    }
}

var previews: [(String, NSImage)] = []
for (name, shell, accent) in palettes
{
    for charging in [false, true]
    {
        let image = NSImage(size: NSSize(width: 2048, height: 1408))
        image.lockFocus()
        drawLid(name: name, shell: shell, accent: accent, charging: charging)
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let assetName = "LidCover-\(name)" + (charging ? "-Charging" : "")
        let folder = output.appendingPathComponent(assetName + ".imageset")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(assetName + ".png"))
        let contents: [String: Any] = ["images": [["filename": assetName + ".png", "idiom": "universal"]], "info": ["author": "xcode", "version": 1]]
        try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
        if !charging { previews.append((name, image)) }
    }
}
let sheet = NSImage(size: NSSize(width: 1600, height: 2600))
sheet.lockFocus()
color("15191E").setFill()
CGRect(x: 0, y: 0, width: 1600, height: 2600).fill()
NSAttributedString(string: "DECORATIVE DS LIDS", attributes: [.font: NSFont.systemFont(ofSize: 36, weight: .semibold), .foregroundColor: NSColor.white, .kern: 4]).draw(at: CGPoint(x: 80, y: 2490))
NSAttributedString(string: "Original companion artwork · DuoDS colorways", attributes: [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: color("AAB4C1")]).draw(at: CGPoint(x: 80, y: 2445))
for (index, preview) in previews.enumerated()
{
    let y = CGFloat(1930 - index * 460)
    preview.1.draw(in: CGRect(x: 420, y: y, width: 600, height: 412.5))
    NSAttributedString(string: preview.0, attributes: [.font: NSFont.systemFont(ofSize: 26, weight: .medium), .foregroundColor: NSColor.white]).draw(at: CGPoint(x: 80, y: y + 198))
}
sheet.unlockFocus()
let previewURL = root.appendingPathComponent("Docs/DecorativeLids.png")
try NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: previewURL)
print("Generated ten lid images and Docs/DecorativeLids.png")
