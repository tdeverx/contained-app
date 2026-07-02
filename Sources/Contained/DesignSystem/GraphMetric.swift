import SwiftUI
import ContainedCore

/// Which live metric a card's sparkline plots. CPU and memory values are normalized against the
/// container's configured resource limits at the app boundary; raw runtime deltas stay in Core.
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

    /// The value plotted for this metric from a stats delta. CPU is a fraction of configured cores;
    /// memory is a fraction of configured memory. Throughput metrics remain bytes per second.
    func value(from delta: StatsDelta,
               snapshot: ContainerSnapshot? = nil,
               normalization: StatsNormalizationContext = .containerSpecific) -> Double {
        switch self {
        case .cpu: return Self.cpuFraction(from: delta, snapshot: snapshot, normalization: normalization)
        case .memory: return Self.memoryFraction(from: delta, snapshot: snapshot, normalization: normalization)
        case .netRx: return delta.netRxBytesPerSec
        case .netTx: return delta.netTxBytesPerSec
        case .diskRead: return delta.blockReadBytesPerSec
        case .diskWrite: return delta.blockWriteBytesPerSec
        }
    }

    /// The value plotted for this metric from durable history. History persists raw samples, then
    /// applies the current normalization mode at display time so old samples remain useful.
    func value(from sample: MetricSample,
               snapshot: ContainerSnapshot? = nil,
               normalization: StatsNormalizationContext = .containerSpecific,
               memoryFallbackBytes: UInt64 = 0) -> Double {
        switch self {
        case .cpu:
            return Self.sanitized(sample.cpuFraction) / normalization.cpuLimit(for: snapshot)
        case .memory:
            let limit = normalization.memoryLimitBytes(for: snapshot, fallback: memoryFallbackBytes)
            guard limit > 0 else { return 0 }
            return Self.sanitized(sample.memoryBytes / Double(limit))
        case .netRx:
            return Self.sanitized(sample.netRxBytesPerSec)
        case .netTx:
            return Self.sanitized(sample.netTxBytesPerSec)
        case .diskRead:
            return Self.sanitized(sample.diskReadBytesPerSec)
        case .diskWrite:
            return Self.sanitized(sample.diskWriteBytesPerSec)
        }
    }

    /// An ultra-compact value for the card footer chips (tight space): decimal percent only below 1%,
    /// `Format.compactRate` for throughput metrics ("0", "1.2K", "34M").
    func chipCaption(from delta: StatsDelta,
                     snapshot: ContainerSnapshot? = nil,
                     normalization: StatsNormalizationContext = .containerSpecific) -> String {
        switch self {
        case .cpu, .memory:
            return Format.compactPercent(value(from: delta, snapshot: snapshot, normalization: normalization))
        case .netRx: return Format.compactRate(delta.netRxBytesPerSec)
        case .netTx: return Format.compactRate(delta.netTxBytesPerSec)
        case .diskRead: return Format.compactRate(delta.blockReadBytesPerSec)
        case .diskWrite: return Format.compactRate(delta.blockWriteBytesPerSec)
        }
    }

    /// A short current-value label for the footer.
    func caption(from delta: StatsDelta,
                 snapshot: ContainerSnapshot? = nil,
                 normalization: StatsNormalizationContext = .containerSpecific) -> String {
        switch self {
        case .cpu, .memory:
            return Format.compactPercent(value(from: delta, snapshot: snapshot, normalization: normalization))
        case .netRx: return Format.rate(delta.netRxBytesPerSec)
        case .netTx: return Format.rate(delta.netTxBytesPerSec)
        case .diskRead: return Format.rate(delta.blockReadBytesPerSec)
        case .diskWrite: return Format.rate(delta.blockWriteBytesPerSec)
        }
    }

    static func cpuFraction(from delta: StatsDelta,
                            snapshot: ContainerSnapshot?,
                            normalization: StatsNormalizationContext = .containerSpecific) -> Double {
        sanitized(delta.cpuCoreFraction) / normalization.cpuLimit(for: snapshot)
    }

    static func memoryFraction(from delta: StatsDelta,
                               snapshot: ContainerSnapshot?,
                               normalization: StatsNormalizationContext = .containerSpecific) -> Double {
        let limit = memoryLimitBytes(for: delta, snapshot: snapshot, normalization: normalization)
        guard limit > 0 else { return 0 }
        return sanitized(Double(delta.memoryUsageBytes) / Double(limit))
    }

    static func memoryLimitBytes(for delta: StatsDelta,
                                 snapshot: ContainerSnapshot?,
                                 normalization: StatsNormalizationContext = .containerSpecific) -> UInt64 {
        normalization.memoryLimitBytes(for: delta, snapshot: snapshot)
    }

    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }
}
