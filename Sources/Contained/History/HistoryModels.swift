import Foundation
import SwiftData

/// Categories of events recorded to the persistent history/timeline.
enum EventKind: String, Codable, CaseIterable, Sendable {
    case lifecycle      // start / stop / remove
    case pull           // image pull
    case build          // image build
    case watchdog       // app-managed restart / unexpected exit
    case healthcheck    // health transitions
    case alert          // anything surfaced as a banner/notification

    var symbol: String {
        switch self {
        case .lifecycle: return "play.circle"
        case .pull: return "arrow.down.circle"
        case .build: return "hammer"
        case .watchdog: return "arrow.clockwise.circle"
        case .healthcheck: return "heart.text.square"
        case .alert: return "exclamationmark.triangle"
        }
    }
}

/// A timestamped event in the persistent activity log.
@Model
final class EventRecord {
    var timestamp: Date
    var containerID: String?
    var kindRaw: String
    var message: String

    init(timestamp: Date, containerID: String?, kind: EventKind, message: String) {
        self.timestamp = timestamp
        self.containerID = containerID
        self.kindRaw = kind.rawValue
        self.message = message
    }

    var kind: EventKind { EventKind(rawValue: kindRaw) ?? .alert }
}

/// A persisted point-in-time resource sample for a container — the basis of the long-term graphs
/// (the "rewind" of the live sparklines).
@Model
final class MetricSample {
    var timestamp: Date
    var containerID: String
    var cpuFraction: Double      // 0…1 of a core-equivalent
    var memoryBytes: Double
    var netRxBytesPerSec: Double
    var netTxBytesPerSec: Double
    var diskReadBytesPerSec: Double
    var diskWriteBytesPerSec: Double

    init(timestamp: Date, containerID: String, cpuFraction: Double, memoryBytes: Double,
         netRxBytesPerSec: Double, netTxBytesPerSec: Double,
         diskReadBytesPerSec: Double, diskWriteBytesPerSec: Double) {
        self.timestamp = timestamp
        self.containerID = containerID
        self.cpuFraction = cpuFraction
        self.memoryBytes = memoryBytes
        self.netRxBytesPerSec = netRxBytesPerSec
        self.netTxBytesPerSec = netTxBytesPerSec
        self.diskReadBytesPerSec = diskReadBytesPerSec
        self.diskWriteBytesPerSec = diskWriteBytesPerSec
    }
}
