#!/usr/bin/env swift
// Renders a per-channel DMG window background PNG (tinted surface + version pill + down-arrow +
// caption). The app icon and the Applications drop-link are drawn by Finder on top at the positions
// make-dmg.sh hands to dmgbuild — this only paints what sits *behind* them.
//
// Usage: swift scripts/dmg-background.swift <out.png> <stable|beta|nightly> <pill-text>
import AppKit

func hex(_ s: String) -> NSColor {
    var h = s; if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt64(h, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "dmg-bg.png"
let channel = args.count > 2 ? args[2] : "stable"
let pillText = args.count > 3 ? args[3] : "1.0.0"

struct Style {
    let bg, pillBg, pillBorder, pillText, arrow, caption: NSColor
    let captionText: String
}
// `bg` is the solid brand color at the BOTTOM of the window; the background fades to transparent
// toward the top so the window's native (light/dark-adaptive) surface shows through there and blends
// with the title bar in either appearance. Pills are solid colored badges (readable on both native
// surfaces); the arrow is a mid-tone that reads on white and dark; captions sit on the solid bottom.
let styles: [String: Style] = [
    "stable": Style(bg: hex("#2E86E0"), pillBg: hex("#2E86E0"), pillBorder: hex("#1E6FC0"),
                    pillText: hex("#FFFFFF"), arrow: hex("#2E86E0"), caption: hex("#FFFFFF"),
                    captionText: "Drag Contained to Applications to install"),
    "beta": Style(bg: hex("#ED9F26"), pillBg: hex("#ED9F26"), pillBorder: hex("#C57E10"),
                  pillText: hex("#4A2B07"), arrow: hex("#C57E10"), caption: hex("#4A2B07"),
                  captionText: "Prerelease software — may contain bugs"),
    "nightly": Style(bg: hex("#4A41A8"), pillBg: hex("#4A41A8"), pillBorder: hex("#6E66C8"),
                     pillText: hex("#FFFFFF"), arrow: hex("#6E5FD6"), caption: hex("#FFFFFF"),
                     captionText: "Bleeding edge — will contain bugs"),
]
let st = styles[channel] ?? styles["stable"]!

// Window content is 380×560 points. `scale` is the pixel density: 1 → 380×560 px, 2 → 760×1120 px.
// make-dmg.sh renders both and folds them into one HiDPI TIFF (tiffutil -cathidpicheck) so Finder
// paints the 2× rep crisply on Retina while keeping the 380×560 logical size — fills edge-to-edge,
// content stays centered. (A lone 2× PNG is treated as 1× by create-dmg/Finder and only a corner
// shows; the TIFF's encoded logical size is what fixes that.)
let scale: CGFloat = args.count > 4 ? CGFloat(Double(args[4]) ?? 1) : 1
let wpt: CGFloat = 380, hpt: CGFloat = 560
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(wpt * scale),
                           pixelsHigh: Int(hpt * scale), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let xf = NSAffineTransform(); xf.scale(by: scale); xf.concat()   // work in points, 2× output

func fromTop(_ topY: CGFloat, _ h: CGFloat) -> CGFloat { hpt - topY - h }  // top-origin → AppKit y

// Surface: the brand color is a low accent along the bottom edge, fading to fully transparent by the
// lower third so the whole upper window shows the native (appearance-adaptive) surface and blends
// with the title bar in light *and* dark mode.
let surface = NSGradient(colors: [st.bg, st.bg, st.bg.withAlphaComponent(0)],
                         atLocations: [0.0, 0.10, 0.42], colorSpace: .sRGB)!
surface.draw(in: NSRect(x: 0, y: 0, width: wpt, height: hpt), angle: 90)

// Centered text helper.
func draw(_ text: String, font: NSFont, color: NSColor, centerX: CGFloat, topY: CGFloat,
          boxWidth: CGFloat) -> NSSize {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color,
                                                 .paragraphStyle: para]
    let size = (text as NSString).size(withAttributes: attrs)
    let rect = NSRect(x: centerX - boxWidth / 2, y: fromTop(topY, size.height), width: boxWidth,
                      height: size.height)
    (text as NSString).draw(in: rect, withAttributes: attrs)
    return size
}

// Version pill (top, centered).
let pillFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let pillSize = (pillText as NSString).size(withAttributes: [.font: pillFont])
let pillW = pillSize.width + 30, pillH: CGFloat = 30, pillTop: CGFloat = 28
let pillRect = NSRect(x: wpt / 2 - pillW / 2, y: fromTop(pillTop, pillH), width: pillW, height: pillH)
let pill = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
st.pillBg.setFill(); pill.fill()
st.pillBorder.setStroke(); pill.lineWidth = 1; pill.stroke()
_ = draw(pillText, font: pillFont, color: st.pillText, centerX: wpt / 2,
         topY: pillTop + (pillH - pillSize.height) / 2, boxWidth: pillW)

// Curly, prominent drag-arrow swooping from the app icon down to Applications.
st.arrow.setStroke(); st.arrow.setFill()
let ax = wpt / 2
let curl = NSBezierPath()
curl.lineWidth = 7
curl.lineCapStyle = .round
curl.lineJoinStyle = .round
curl.move(to: NSPoint(x: ax, y: fromTop(250, 0)))
curl.curve(to: NSPoint(x: ax, y: fromTop(348, 0)),
           controlPoint1: NSPoint(x: ax - 54, y: fromTop(284, 0)),
           controlPoint2: NSPoint(x: ax + 54, y: fromTop(316, 0)))
curl.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: ax, y: fromTop(374, 0)))          // tip
head.line(to: NSPoint(x: ax - 16, y: fromTop(346, 0)))
head.line(to: NSPoint(x: ax + 16, y: fromTop(346, 0)))
head.close(); head.fill()

// Caption (bottom, centered).
_ = draw(st.captionText, font: NSFont.systemFont(ofSize: 12), color: st.caption,
         centerX: wpt / 2, topY: 512, boxWidth: wpt - 40)

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
