import Foundation
import ContainedCore

enum ContainerFormStateMemoryFormatter {
    /// Parse a `--memory` spec ("512M", "1G", "2g", bare bytes) into gigabytes.
    static func parseGB(_ spec: String) -> Double? {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard let last = trimmed.last else { return nil }
        if last.isLetter {
            guard let value = Double(trimmed.dropLast()) else { return nil }
            switch last.uppercased() {
            case "G": return value
            case "M": return value / 1024
            case "K": return value / (1024 * 1024)
            case "T": return value * 1024
            default: return nil
            }
        }
        return Double(trimmed).map { $0 / 1_073_741_824 }
    }

    /// Format gigabytes as a `--memory` spec, using `M` for fractional values.
    static func spec(gb: Double) -> String {
        gb.rounded() == gb ? "\(Int(gb))G" : "\(Int(gb * 1024))M"
    }

    static func readout(_ spec: String, fallbackGB: Double) -> String {
        let gb = parseGB(spec) ?? fallbackGB
        if gb < 1 { return "\(Int(gb * 1024)) MB" }
        return gb.rounded() == gb ? "\(Int(gb)) GB" : String(format: "%.1f GB", gb)
    }
}
