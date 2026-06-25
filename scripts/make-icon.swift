#!/usr/bin/env swift
// Renders the Contained app icon (a glass "container" mark on a gradient) to a 1024×1024 PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size = 1024.0

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let rect = NSRect(x: 0, y: 0, width: size, height: size)
// Rounded-rect gradient background (macOS icon "squircle" proportions).
let inset = size * 0.08
let bg = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                      xRadius: size * 0.22, yRadius: size * 0.22)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.52, blue: 0.92, alpha: 1),
    NSColor(calibratedRed: 0.33, green: 0.29, blue: 0.72, alpha: 1),
])!
gradient.draw(in: bg, angle: -90)

// Container glyph (SF Symbol) in white.
if let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    let glyph = symbol.withSymbolConfiguration(config) ?? symbol
    let tinted = NSImage(size: glyph.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = NSRect(origin: .zero, size: glyph.size)
    glyph.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()
    let gw = size * 0.5, gh = gw * (glyph.size.height / glyph.size.width)
    tinted.draw(in: NSRect(x: (size - gw) / 2, y: (size - gh) / 2, width: gw, height: gh),
                from: .zero, operation: .sourceOver, fraction: 0.95)
}

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
