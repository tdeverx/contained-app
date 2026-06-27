import SwiftUI

enum Format {
    static func bytes(_ value: UInt64) -> String {
        value.formatted(.byteCount(style: .file))
    }
    static func bytes(_ value: Double) -> String {
        UInt64(max(0, value)).formatted(.byteCount(style: .file))
    }
    static func rate(_ bytesPerSec: Double) -> String {
        "\(bytes(bytesPerSec))/s"
    }
    /// A tight throughput readout for the card footer chips: "0", "1.2K", "34M" (bytes/s, no unit
    /// words or "/s" — the chip's up/down arrow already carries that). Keeps digits to a minimum
    /// with one decimal only while the scaled value is under 10.
    static func compactRate(_ bytesPerSec: Double) -> String {
        let value = max(0, bytesPerSec)
        if value < 1 { return "0" }
        for (scale, suffix) in [(1e9, "G"), (1e6, "M"), (1e3, "K")] where value >= scale {
            let scaled = value / scale
            return scaled < 10 ? String(format: "%.1f%@", scaled, suffix)
                               : String(format: "%.0f%@", scaled, suffix)
        }
        return String(format: "%.0f", value)
    }
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Compact relative uptime, e.g. "2h", "6d", "just now".
    static func uptime(since date: Date?, now: Date = .now) -> String {
        guard let date else { return "—" }
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    /// Render a byte count as a `--memory`-friendly spec (e.g. "1G", "512M"), using the largest
    /// suffix that divides evenly, else raw bytes.
    static func memorySpec(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "" }
        let units: [(UInt64, String)] = [(1 << 30, "G"), (1 << 20, "M"), (1 << 10, "K")]
        for (size, suffix) in units where bytes % size == 0 { return "\(bytes / size)\(suffix)" }
        return "\(bytes)"
    }

    /// Strip the registry/namespace for a compact image label, keeping repo:tag.
    static func shortImage(_ reference: String) -> String {
        reference.replacingOccurrences(of: "docker.io/library/", with: "")
            .replacingOccurrences(of: "docker.io/", with: "")
    }
}
