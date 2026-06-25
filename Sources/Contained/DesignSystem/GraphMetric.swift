import SwiftUI
import ContainedCore

/// Which live metric a card's sparkline plots. Values are derived from `StatsDelta` and normalized
/// to a 0...1-ish range for the sparkline (which auto-scales to its own max anyway).
enum GraphMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case cpu, memory, netRx, netTx, diskRead, diskWrite
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .netRx: return "Net In"
        case .netTx: return "Net Out"
        case .diskRead: return "Disk Read"
        case .diskWrite: return "Disk Write"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .netRx: return "arrow.down.circle"
        case .netTx: return "arrow.up.circle"
        case .diskRead: return "arrow.down.doc"
        case .diskWrite: return "arrow.up.doc"
        }
    }

    /// The raw value plotted for this metric from a stats delta.
    func value(from delta: StatsDelta) -> Double {
        switch self {
        case .cpu: return delta.cpuCoreFraction
        case .memory: return delta.memoryFraction
        case .netRx: return delta.netRxBytesPerSec
        case .netTx: return delta.netTxBytesPerSec
        case .diskRead: return delta.blockReadBytesPerSec
        case .diskWrite: return delta.blockWriteBytesPerSec
        }
    }

    /// A short current-value label for the footer.
    func caption(from delta: StatsDelta) -> String {
        switch self {
        case .cpu: return Format.percent(delta.cpuCoreFraction)
        case .memory: return Format.percent(delta.memoryFraction)
        case .netRx: return Format.rate(delta.netRxBytesPerSec)
        case .netTx: return Format.rate(delta.netTxBytesPerSec)
        case .diskRead: return Format.rate(delta.blockReadBytesPerSec)
        case .diskWrite: return Format.rate(delta.blockWriteBytesPerSec)
        }
    }
}
