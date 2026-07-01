import Foundation
import SwiftData

/// Categories of events recorded to the persistent history/timeline.
enum EventKind: String, Codable, CaseIterable, Sendable {
    case lifecycle      // start / stop / remove
    case image          // image load / update / maintenance
    case compose        // compose import / translation
    case system         // runtime service / volumes / networks
    case registry       // registry login state
    case ui             // user-facing app messages
    case pull           // image pull
    case build          // image build
    case watchdog       // app-managed restart / unexpected exit
    case healthcheck    // health transitions
    case alert          // anything surfaced as a banner/notification

    var symbol: String {
        switch self {
        case .lifecycle: return "play.circle"
        case .image: return "square.stack.3d.up"
        case .compose: return "shippingbox.and.arrow.backward"
        case .system: return "gearshape.2"
        case .registry: return "key"
        case .ui: return "bubble"
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
    /// Whether the user has seen this event in the Activity panel. New events start unread so the
    /// toolbar bell can surface a badge; opening (and dismissing) the panel marks them read. Defaulted
    /// so the SwiftData schema migrates in place for stores written before this column existed.
    var isRead: Bool = false

    init(timestamp: Date, containerID: String?, kind: EventKind, message: String, isRead: Bool = false) {
        self.timestamp = timestamp
        self.containerID = containerID
        self.kindRaw = kind.rawValue
        self.message = message
        self.isRead = isRead
    }

    init(snapshot: EventRecordSnapshot) {
        self.timestamp = snapshot.timestamp
        self.containerID = snapshot.containerID
        self.kindRaw = snapshot.kindRaw
        self.message = snapshot.message
    }

    var kind: EventKind { EventKind(rawValue: kindRaw) ?? .alert }
}

struct EventRecordSnapshot: Codable, Equatable {
    var timestamp: Date
    var containerID: String?
    var kindRaw: String
    var message: String

    init(_ record: EventRecord) {
        timestamp = record.timestamp
        containerID = record.containerID
        kindRaw = record.kindRaw
        message = record.message
    }
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

    init(snapshot: MetricSampleSnapshot) {
        self.timestamp = snapshot.timestamp
        self.containerID = snapshot.containerID
        self.cpuFraction = snapshot.cpuFraction
        self.memoryBytes = snapshot.memoryBytes
        self.netRxBytesPerSec = snapshot.netRxBytesPerSec
        self.netTxBytesPerSec = snapshot.netTxBytesPerSec
        self.diskReadBytesPerSec = snapshot.diskReadBytesPerSec
        self.diskWriteBytesPerSec = snapshot.diskWriteBytesPerSec
    }
}

struct MetricSampleSnapshot: Codable, Equatable {
    var timestamp: Date
    var containerID: String
    var cpuFraction: Double
    var memoryBytes: Double
    var netRxBytesPerSec: Double
    var netTxBytesPerSec: Double
    var diskReadBytesPerSec: Double
    var diskWriteBytesPerSec: Double

    init(_ sample: MetricSample) {
        timestamp = sample.timestamp
        containerID = sample.containerID
        cpuFraction = sample.cpuFraction
        memoryBytes = sample.memoryBytes
        netRxBytesPerSec = sample.netRxBytesPerSec
        netTxBytesPerSec = sample.netTxBytesPerSec
        diskReadBytesPerSec = sample.diskReadBytesPerSec
        diskWriteBytesPerSec = sample.diskWriteBytesPerSec
    }
}
