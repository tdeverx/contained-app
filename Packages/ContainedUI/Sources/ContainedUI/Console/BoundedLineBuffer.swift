import Foundation
import Observation
import OSLog

public extension UI.Console {
    struct LineBlock: Identifiable, Equatable, Sendable {
        public fileprivate(set) var id: UInt64
        public fileprivate(set) var text: String
        public fileprivate(set) var lineCount: Int
        fileprivate var entries: [LineEntry]
        fileprivate var utf8Count: Int
    }

    struct BoundedLineBuffer: Equatable, Sendable {
        public let capacity: Int
        public private(set) var blocks: [LineBlock] = []
        public private(set) var lineCount = 0
        public private(set) var copyText = ""
        private var nextID: UInt64 = 0

        public init(capacity: Int) {
            self.capacity = max(capacity, 1)
        }

        public mutating func append(_ lines: [String]) {
            guard !lines.isEmpty else { return }
            for line in lines { appendLine(line) }
            evictOverflow()
            copyText = blocks.flatMap(\.entries).map(\.text).joined(separator: "\n")
        }

        public mutating func clear() {
            blocks.removeAll(keepingCapacity: true)
            lineCount = 0
            copyText = ""
        }

        private mutating func appendLine(_ text: String) {
            let entry = LineEntry(id: nextID, text: text)
            nextID &+= 1
            let bytes = text.utf8.count
            if var last = blocks.last,
               last.lineCount < 40,
               last.utf8Count + 1 + bytes <= 8_192 {
                last.entries.append(entry)
                last.lineCount += 1
                last.utf8Count += 1 + bytes
                last.text = last.entries.map(\.text).joined(separator: "\n")
                blocks[blocks.count - 1] = last
            } else {
                blocks.append(LineBlock(id: entry.id, text: text, lineCount: 1,
                                        entries: [entry], utf8Count: bytes))
            }
            lineCount += 1
        }

        private mutating func evictOverflow() {
            var overflow = lineCount - capacity
            while overflow > 0, !blocks.isEmpty {
                if blocks[0].lineCount <= overflow {
                    overflow -= blocks[0].lineCount
                    lineCount -= blocks[0].lineCount
                    blocks.removeFirst()
                } else {
                    var first = blocks[0]
                    first.entries.removeFirst(overflow)
                    first.lineCount = first.entries.count
                    first.utf8Count = first.entries.reduce(0) { $0 + $1.text.utf8.count }
                        + max(first.entries.count - 1, 0)
                    first.text = first.entries.map(\.text).joined(separator: "\n")
                    lineCount -= overflow
                    overflow = 0
                    blocks[0] = first
                }
            }
        }
    }

    @MainActor
    @Observable
    final class StreamBuffer {
        private static let signposter = OSSignposter(subsystem: "app.contained.ContainedUI",
                                                     category: "performance.console")
        public private(set) var output: BoundedLineBuffer
        public private(set) var publicationCount = 0

        @ObservationIgnored private var carry = ""
        @ObservationIgnored private var pending: [String] = []
        @ObservationIgnored private var flushTask: Task<Void, Never>?
        @ObservationIgnored private var lastFlush = Date.distantPast

        public init(capacity: Int) {
            output = BoundedLineBuffer(capacity: capacity)
        }

        public func enqueue(_ chunk: String) {
            let combined = carry + chunk
            guard let newline = combined.lastIndex(of: "\n") else {
                carry = combined
                return
            }
            pending.append(contentsOf: combined[..<newline]
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init))
            carry = String(combined[combined.index(after: newline)...])

            let elapsed = Date().timeIntervalSince(lastFlush)
            if pending.count >= 200, elapsed >= 0.1 {
                flush()
            } else {
                scheduleFlush(after: max(0.1 - elapsed, 0))
            }
        }

        public func finish() {
            if !carry.isEmpty { pending.append(carry) }
            carry = ""
            flush()
        }

        public func cancel() {
            finish()
            flushTask?.cancel()
            flushTask = nil
        }

        public func clear() {
            flushTask?.cancel()
            flushTask = nil
            carry = ""
            pending.removeAll(keepingCapacity: true)
            output.clear()
            publicationCount &+= 1
        }

        private func scheduleFlush(after delay: TimeInterval) {
            guard flushTask == nil else { return }
            flushTask = Task { @MainActor [weak self] in
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                self?.flush()
            }
        }

        private func flush() {
            flushTask?.cancel()
            flushTask = nil
            guard !pending.isEmpty else { return }
            let interval = Self.signposter.beginInterval("ConsolePublication")
            defer { Self.signposter.endInterval("ConsolePublication", interval) }
            output.append(pending)
            pending.removeAll(keepingCapacity: true)
            lastFlush = Date()
            publicationCount &+= 1
        }
    }
}

fileprivate struct LineEntry: Equatable, Sendable {
    let id: UInt64
    let text: String
}
