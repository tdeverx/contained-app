/// A runtime-neutral metric that can be graphed from live or persisted container stats.
public enum GraphMetric: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case cpu, memory, netRx, netTx, diskRead, diskWrite

    public var id: String { rawValue }

    public func value(from delta: StatsDelta,
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

    public func value(from sample: any MetricHistorySample,
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

    public static func cpuFraction(from delta: StatsDelta,
                                   snapshot: ContainerSnapshot?,
                                   normalization: StatsNormalizationContext = .containerSpecific) -> Double {
        sanitized(delta.cpuCoreFraction) / normalization.cpuLimit(for: snapshot)
    }

    public static func memoryFraction(from delta: StatsDelta,
                                      snapshot: ContainerSnapshot?,
                                      normalization: StatsNormalizationContext = .containerSpecific) -> Double {
        let limit = memoryLimitBytes(for: delta, snapshot: snapshot, normalization: normalization)
        guard limit > 0 else { return 0 }
        return sanitized(Double(delta.memoryUsageBytes) / Double(limit))
    }

    public static func memoryLimitBytes(for delta: StatsDelta,
                                        snapshot: ContainerSnapshot?,
                                        normalization: StatsNormalizationContext = .containerSpecific) -> UInt64 {
        normalization.memoryLimitBytes(for: delta, snapshot: snapshot)
    }

    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }
}

public protocol MetricHistorySample {
    var cpuFraction: Double { get }
    var memoryBytes: Double { get }
    var netRxBytesPerSec: Double { get }
    var netTxBytesPerSec: Double { get }
    var diskReadBytesPerSec: Double { get }
    var diskWriteBytesPerSec: Double { get }
}
