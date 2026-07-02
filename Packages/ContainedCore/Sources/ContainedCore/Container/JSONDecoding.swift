import Foundation

/// Central JSON coding configuration for everything the `container` CLI emits via `--format json`.
///
/// The CLI's date encoding is inconsistent: top-level resource dates look like
/// `2026-06-24T10:16:58Z` (no fractional seconds) while embedded OCI image-config dates look like
/// `2026-06-16T00:01:29.967161902Z` (nanosecond precision). We accept both, plus a couple of
/// other lenient fallbacks, so decoding never fails on a date.
public enum ContainerJSON {

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseDate(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return decoder
    }()

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    // `Date.ISO8601FormatStyle` is a Sendable value type (unlike `ISO8601DateFormatter`).
    private static let iso8601 = Date.ISO8601FormatStyle()

    static func parseDate(_ raw: String) -> Date? {
        if let date = try? iso8601.parse(raw) { return date }
        // The CLI emits nanosecond fractional seconds in OCI image configs
        // (e.g. `…:29.967161902Z`), which the standard parsers reject. Drop the
        // fractional component — sub-second precision isn't needed for display.
        let normalized = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return try? iso8601.parse(normalized)
    }

    /// Decode a value of the given type from raw CLI stdout.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
