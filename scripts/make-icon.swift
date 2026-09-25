// Draws the app icon: two usage meters (5-hour and weekly) on a warm rounded square.
// Usage: swift scripts/make-icon.swift <out.png>   (1024x1024; make-icon.sh turns it into .icns)
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

// macOS icon grid: an 824pt rounded square centred on the 1024 canvas, with a soft drop shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28).cgColor)
color(0xD9774B).setFill()
tilePath.fill()
ctx.restoreGState()

ctx.saveGState()
tilePath.addClip()
NSGradient(starting: color(0xEE9A6A), ending: color(0xC45A33))!.draw(in: tile, angle: -90)
// A faint highlight across the top edge.
NSGradient(starting: color(0xFFFFFF, 0.18), ending: color(0xFFFFFF, 0))!
    .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
ctx.restoreGState()

// Two meters: tracks, fills, and a small end cap marking the current level.
let barWidth: CGFloat = 584, barHeight: CGFloat = 104
let barX = (size - barWidth) / 2
for (y, fraction) in [(CGFloat(566), CGFloat(0.63)), (CGFloat(354), CGFloat(0.42))] {
    let track = NSRect(x: barX, y: y, width: barWidth, height: barHeight)
    color(0x5A2412, 0.30).setFill()
    NSBezierPath(roundedRect: track, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()

    let fill = NSRect(x: barX, y: y, width: max(barHeight, barWidth * fraction), height: barHeight)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: color(0x5A2412, 0.35).cgColor)
    color(0xFFF8F2).setFill()
    NSBezierPath(roundedRect: fill, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
    ctx.restoreGState()
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
