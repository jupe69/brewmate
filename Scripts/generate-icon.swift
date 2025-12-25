#!/usr/bin/swift

import AppKit
import Foundation

// App icon generator for Taphouse
// Run with: swift generate-icon.swift

// macOS requires specific pixel sizes for each icon slot
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func generateIcon(size: Int) -> Data? {
    // Create bitmap at exact pixel size (not point size)
    guard let bitmapRep = NSBitmapImageRep(
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
    ) else { return nil }

    bitmapRep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // Background gradient (warm brown/orange - Homebrew colors)
    let gradient = NSGradient(
        starting: NSColor(red: 0.98, green: 0.65, blue: 0.35, alpha: 1.0),
        ending: NSColor(red: 0.90, green: 0.50, blue: 0.25, alpha: 1.0)
    )

    // Rounded rect background
    let cornerRadius = CGFloat(size) * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient?.draw(in: bgPath, angle: -45)

    // Draw mug icon
    let mugColor = NSColor.white
    mugColor.setFill()
    mugColor.setStroke()

    let scale = CGFloat(size) / 512.0
    let centerX = CGFloat(size) / 2
    let centerY = CGFloat(size) / 2

    // Mug body
    let mugWidth = 160 * scale
    let mugHeight = 180 * scale
    let mugX = centerX - mugWidth / 2 - 15 * scale
    let mugY = centerY - mugHeight / 2 - 20 * scale

    let mugRect = NSRect(x: mugX, y: mugY, width: mugWidth, height: mugHeight)
    let mugPath = NSBezierPath(roundedRect: mugRect, xRadius: 15 * scale, yRadius: 15 * scale)
    mugPath.lineWidth = max(12 * scale, 1)
    mugPath.stroke()

    // Mug handle
    let handlePath = NSBezierPath()
    let handleX = mugX + mugWidth
    let handleCenterY = mugY + mugHeight / 2
    handlePath.move(to: NSPoint(x: handleX, y: handleCenterY + 45 * scale))
    handlePath.curve(
        to: NSPoint(x: handleX, y: handleCenterY - 45 * scale),
        controlPoint1: NSPoint(x: handleX + 60 * scale, y: handleCenterY + 45 * scale),
        controlPoint2: NSPoint(x: handleX + 60 * scale, y: handleCenterY - 45 * scale)
    )
    handlePath.lineWidth = max(12 * scale, 1)
    handlePath.lineCapStyle = .round
    handlePath.stroke()

    // Steam lines (only draw for larger icons)
    if size >= 64 {
        let steamX = centerX - 25 * scale
        let steamBaseY = mugY + mugHeight + 15 * scale

        NSColor.white.withAlphaComponent(0.85).setStroke()

        for i in 0..<3 {
            let offsetX = CGFloat(i - 1) * 35 * scale
            let steamPath = NSBezierPath()
            steamPath.move(to: NSPoint(x: steamX + offsetX, y: steamBaseY))

            let waveHeight = 50 * scale
            let waveWidth = 12 * scale
            steamPath.curve(
                to: NSPoint(x: steamX + offsetX + waveWidth, y: steamBaseY + waveHeight),
                controlPoint1: NSPoint(x: steamX + offsetX - waveWidth, y: steamBaseY + waveHeight * 0.33),
                controlPoint2: NSPoint(x: steamX + offsetX + waveWidth * 2, y: steamBaseY + waveHeight * 0.66)
            )

            steamPath.lineWidth = max(6 * scale, 1)
            steamPath.lineCapStyle = .round
            steamPath.stroke()
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep.representation(using: .png, properties: [:])
}

// Create output directory
let outputDir = "../Taphouse/Assets.xcassets/AppIcon.appiconset"

// Generate icons
for (size, filename) in sizes {
    if let pngData = generateIcon(size: size) {
        let filePath = (outputDir as NSString).appendingPathComponent(filename)
        try? pngData.write(to: URL(fileURLWithPath: filePath))
        print("Generated: \(filename) (\(size)x\(size))")
    }
}

// Generate Contents.json
let contentsJSON = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let contentsPath = (outputDir as NSString).appendingPathComponent("Contents.json")
try? contentsJSON.write(toFile: contentsPath, atomically: true, encoding: .utf8)
print("\nApp icon generated successfully!")
