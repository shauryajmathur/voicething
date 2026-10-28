import AppKit
import Foundation
let root = CommandLine.arguments[1]
let destination = URL(fileURLWithPath: root).appendingPathComponent("Sources/VoiceThingCore/Resources/Brand")
func render(_ size: Int, markOnly: Bool = false) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    if !markOnly {
        let tile = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 214, yRadius: 214)
        NSGradient(starting: NSColor(white: 0.16, alpha: 1), ending: NSColor(white: 0.055, alpha: 1))!
            .draw(in: tile, angle: -65)
        NSColor(white: 1, alpha: 0.13).setStroke()
        tile.lineWidth = 2
        tile.stroke()
    }
    let strokes = NSBezierPath()
    strokes.appendRoundedRect(NSRect(x: 350, y: 282, width: 112, height: 460), xRadius: 56, yRadius: 56)
    strokes.appendRoundedRect(NSRect(x: 562, y: 382, width: 112, height: 260), xRadius: 56, yRadius: 56)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.83, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.94, alpha: 1),
        NSColor(calibratedRed: 0.81, green: 0.75, blue: 0.66, alpha: 1)
    ])!.draw(in: strokes, angle: -40)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
try render(1024).write(to: destination.appendingPathComponent("VoiceThing.png"))
try render(128, markOnly: true).write(to: destination.appendingPathComponent("VoiceThingMark.png"))
let iconset = URL(fileURLWithPath: root).appendingPathComponent(".build/VoiceThing.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size*2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
