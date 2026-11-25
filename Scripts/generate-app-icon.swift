import AppKit
import Foundation

let background = NSColor.white
let emoji = "🌞"

func renderIcon(size: Int, to url: URL) throws {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap"])
    }

    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    background.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    let dimension = CGFloat(size)
    let fontSize = dimension * 0.62
    let font = NSFont(name: "Apple Color Emoji", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let text = NSAttributedString(string: emoji, attributes: attributes)
    let textSize = text.size()
    let origin = NSPoint(
        x: (dimension - textSize.width) / 2,
        y: (dimension - textSize.height) / 2
    )
    text.draw(at: origin)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }

    try png.write(to: url)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for entry in sizes {
    try renderIcon(size: entry.pixels, to: outputDir.appendingPathComponent(entry.name))
    print("Wrote \(entry.name) (\(entry.pixels)px)")
}
