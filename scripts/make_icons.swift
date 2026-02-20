// Renders icon.svg into an AppIcon.iconset directory at the required macOS sizes.
// Usage: make_icons <input.svg> <output.iconset>
import Cocoa

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: make_icons <input.svg> <output.iconset>\n", stderr)
    exit(1)
}

let svgPath     = CommandLine.arguments[1]
let iconsetPath = CommandLine.arguments[2]

// Initialize AppKit so NSImage / NSGraphicsContext work in a CLI context.
_ = NSApplication.shared

guard let source = NSImage(contentsOfFile: svgPath) else {
    fputs("Error: could not load \(svgPath)\n", stderr)
    exit(1)
}
// Fix the canonical size so the SVG is always rasterised from 512×512 geometry.
source.size = NSSize(width: 512, height: 512)

try? FileManager.default.createDirectory(atPath: iconsetPath,
                                         withIntermediateDirectories: true)

// Each entry: (logical point size, scale factor)
let entries: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

for (logical, scale) in entries {
    let pixels   = logical * scale
    let filename = scale == 1
        ? "icon_\(logical)x\(logical).png"
        : "icon_\(logical)x\(logical)@\(scale)x.png"

    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { continue }

    NSGraphicsContext.saveGraphicsState()
    if let gc = NSGraphicsContext(bitmapImageRep: bmp) {
        gc.imageInterpolation = .high
        NSGraphicsContext.current = gc
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                    from: .zero, operation: .copy, fraction: 1.0)
    }
    NSGraphicsContext.restoreGraphicsState()

    if let png = bmp.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "\(iconsetPath)/\(filename)")
        try? png.write(to: url)
        print("  \(filename)")
    }
}
