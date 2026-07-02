import Foundation
import ContainedCore

/// Parses the ANSI table emitted by `container stats --format table`.
///
/// Apple container currently streams live stats only in table mode. Structured formats are static,
/// so this parser is intentionally small, dependency-free, and isolated behind the runtime client
/// boundary until Apple exposes a stable structured streaming surface.
public struct ContainerStatsTableParser: Sendable {
    private static let clearScreen = "\u{001B}[H\u{001B}[J"
    private static let columns = ["Container ID", "Cpu %", "Memory Usage", "Net Rx/Tx", "Block I/O", "Pids"]

    private var buffer = ""
    private var lastEmittedFrame: String?

    public init() {}

    public mutating func append(_ chunk: String) -> [RuntimeStatsSnapshot] {
        buffer += chunk
        guard let frame = Self.latestParseableFrame(in: buffer), frame != lastEmittedFrame else { return [] }
        guard let snapshots = Self.parseFrame(frame), !snapshots.isEmpty else { return [] }
        lastEmittedFrame = frame
        trimBuffer()
        return snapshots
    }

    public static func parseLatestFrame(in output: String) -> [RuntimeStatsSnapshot] {
        guard let frame = latestParseableFrame(in: output),
              let snapshots = parseFrame(frame) else {
            return []
        }
        return snapshots
    }

    public static func parseFrame(_ frame: String) -> [RuntimeStatsSnapshot]? {
        let lines = stripANSI(from: frame)
            .components(separatedBy: .newlines)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let headerIndex = lines.lastIndex(where: isHeaderLine) else { return nil }
        let header = lines[headerIndex]
        let starts = columns.compactMap { column -> Int? in
            guard let range = header.range(of: column) else { return nil }
            return header.distance(from: header.startIndex, to: range.lowerBound)
        }
        guard starts.count == columns.count else { return nil }

        var snapshots: [RuntimeStatsSnapshot] = []
        for row in lines.dropFirst(headerIndex + 1) {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("error collecting stats") { continue }
            if let snapshot = parseRow(row, starts: starts) {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    private mutating func trimBuffer() {
        let frames = buffer.components(separatedBy: Self.clearScreen)
        guard frames.count > 3 else { return }
        buffer = frames.suffix(2).joined(separator: Self.clearScreen)
    }

    private static func latestParseableFrame(in output: String) -> String? {
        output.components(separatedBy: clearScreen)
            .reversed()
            .first { frame in
                let stripped = stripANSI(from: frame)
                return isHeaderLine(stripped) && !stripped.contains("error collecting stats")
            }
    }

    private static func isHeaderLine(_ line: String) -> Bool {
        columns.allSatisfy { line.contains($0) }
    }

    private static func parseRow(_ row: String, starts: [Int]) -> RuntimeStatsSnapshot? {
        let fields = starts.enumerated().map { index, start in
            let end = index + 1 < starts.count ? starts[index + 1] : nil
            return field(in: row, start: start, end: end)
        }
        guard fields.count == columns.count else { return nil }
        let id = fields[0]
        guard !id.isEmpty, id != "Container ID" else { return nil }
        let memory = parseBytePair(fields[2])
        let network = parseBytePair(fields[3])
        let block = parseBytePair(fields[4])

        return RuntimeStatsSnapshot(
            id: id,
            cpuCoreFraction: parseCPU(fields[1]),
            memoryUsageBytes: memory.first,
            memoryLimitBytes: memory.second,
            blockReadBytes: block.first,
            blockWriteBytes: block.second,
            networkRxBytes: network.first,
            networkTxBytes: network.second,
            numProcesses: UInt64(fields[5])
        )
    }

    private static func field(in line: String, start: Int, end: Int?) -> String {
        guard start < line.count else { return "" }
        let lower = line.index(line.startIndex, offsetBy: start)
        let upper: String.Index
        if let end, end < line.count {
            upper = line.index(line.startIndex, offsetBy: end)
        } else {
            upper = line.endIndex
        }
        return String(line[lower..<upper]).trimmingCharacters(in: .whitespaces)
    }

    private static func parseCPU(_ value: String) -> Double? {
        let cleaned = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
        guard cleaned != "--", let percent = Double(cleaned) else { return nil }
        return percent / 100
    }

    private static func parseBytePair(_ value: String) -> (first: UInt64?, second: UInt64?) {
        let parts = value.components(separatedBy: " / ")
        guard parts.count == 2 else { return (nil, nil) }
        return (parseBytes(parts[0]), parseBytes(parts[1]))
    }

    private static func parseBytes(_ value: String) -> UInt64? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned != "--" else { return nil }
        let pieces = cleaned.split(whereSeparator: \.isWhitespace)
        guard let number = pieces.first.flatMap({ Double($0) }) else { return nil }
        let unit = pieces.dropFirst().first.map { String($0).lowercased() } ?? "b"
        let multiplier: Double
        switch unit {
        case "b", "byte", "bytes":
            multiplier = 1
        case "kb":
            multiplier = 1_000
        case "mb":
            multiplier = 1_000_000
        case "gb":
            multiplier = 1_000_000_000
        case "tb":
            multiplier = 1_000_000_000_000
        case "kib":
            multiplier = 1_024
        case "mib":
            multiplier = 1_024 * 1_024
        case "gib":
            multiplier = 1_024 * 1_024 * 1_024
        case "tib":
            multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default:
            return nil
        }
        return UInt64((number * multiplier).rounded())
    }

    private static func stripANSI(from string: String) -> String {
        let pattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
}
