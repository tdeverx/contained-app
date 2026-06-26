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
let styles: [String: Style] = [
    "stable": Style(bg: hex("#F3F7FD"), pillBg: hex("#E6F1FB"), pillBorder: hex("#B5D4F4"),
                    pillText: hex("#0C447C"), arrow: hex("#85B7EB"), caption: hex("#5F8FBF"),
                    captionText: "Drag Contained to Applications to install"),
    "beta": Style(bg: hex("#FBF3E6"), pillBg: hex("#FAEEDA"), pillBorder: hex("#FAC775"),
                  pillText: hex("#633806"), arrow: hex("#E0B062"), caption: hex("#A8884E"),
                  captionText: "Prerelease software — may contain bugs"),
    "nightly": Style(bg: hex("#191630"), pillBg: hex("#2A2550"), pillBorder: hex("#3C3489"),
                     pillText: hex("#CECBF6"), arrow: hex("#7F77DD"), caption: hex("#8983C4"),
                     captionText: "Bleeding edge — will contain bugs"),
]
let st = styles[channel] ?? styles["stable"]!

// Window content is 380×560 points; render at 2× for retina.
let scale: CGFloat = 2
let wpt: CGFloat = 380, hpt: CGFloat = 560
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(wpt * scale),
                           pixelsHigh: Int(hpt * scale), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let xf = NSAffineTransform(); xf.scale(by: scale); xf.concat()   // work in points, 2× output

func fromTop(_ topY: CGFloat, _ h: CGFloat) -> CGFloat { hpt - topY - h }  // top-origin → AppKit y

// Surface.
st.bg.setFill()
NSRect(x: 0, y: 0, width: wpt, height: hpt).fill()

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

// Down-arrow between the two icon slots (app icon ~180, Applications ~430).
st.arrow.setStroke(); st.arrow.setFill()
let ax = wpt / 2
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: ax, y: fromTop(270, 0)))
shaft.line(to: NSPoint(x: ax, y: fromTop(330, 0)))
shaft.lineWidth = 3; shaft.lineCapStyle = .round; shaft.stroke()
let head = NSBezierPath()
head.move(to: NSPoint(x: ax, y: fromTop(344, 0)))
head.line(to: NSPoint(x: ax - 11, y: fromTop(330, 0)))
head.line(to: NSPoint(x: ax + 11, y: fromTop(330, 0)))
head.close(); head.fill()

// Caption (bottom, centered).
_ = draw(st.captionText, font: NSFont.systemFont(ofSize: 12), color: st.caption,
         centerX: wpt / 2, topY: 512, boxWidth: wpt - 40)

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
