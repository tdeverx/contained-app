import Foundation

/// One element of `container stats --format json`.
///
/// IMPORTANT: every byte/usec field is a **cumulative** counter since container start. CPU percent
/// and per-interval throughput must be computed as deltas between two samples — see `Core.Metrics.StatsDelta`.
public extension Core.Metrics {
struct ContainerStats: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let cpuUsageUsec: UInt64?
    public let memoryUsageBytes: UInt64?
    public let memoryLimitBytes: UInt64?
    public let blockReadBytes: UInt64?
    public let blockWriteBytes: UInt64?
    public let networkRxBytes: UInt64?
    public let networkTxBytes: UInt64?
    public let numProcesses: UInt64?

    public var memoryFraction: Double? {
        guard let used = memoryUsageBytes, let limit = memoryLimitBytes, limit > 0 else { return nil }
        return Double(used) / Double(limit)
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Metrics.ContainerStats {
        Core.Metrics.ContainerStats(id: runtimeKind.scopedID(for: id),
                                    cpuUsageUsec: cpuUsageUsec,
                                    memoryUsageBytes: memoryUsageBytes,
                                    memoryLimitBytes: memoryLimitBytes,
                                    blockReadBytes: blockReadBytes,
                                    blockWriteBytes: blockWriteBytes,
                                    networkRxBytes: networkRxBytes,
                                    networkTxBytes: networkTxBytes,
                                    numProcesses: numProcesses)
    }
}

/// Runtime-agnostic resource counters parsed from a streaming source.
///
/// Apple container's live table stream reports CPU as an already-computed percent and reports
/// memory/network/block values as current cumulative counters. Keeping this separate from
/// `Core.Metrics.ContainerStats` lets future runtime adapters, including Docker Engine API streams, publish the
/// same shape without pretending they came from Apple container's JSON schema.
struct RuntimeStatsSnapshot: Sendable, Identifiable, Hashable {
    public let id: String
    public let cpuCoreFraction: Double?
    public let memoryUsageBytes: UInt64?
    public let memoryLimitBytes: UInt64?
    public let blockReadBytes: UInt64?
    public let blockWriteBytes: UInt64?
    public let networkRxBytes: UInt64?
    public let networkTxBytes: UInt64?
    public let numProcesses: UInt64?

    public init(id: String,
                cpuCoreFraction: Double?,
                memoryUsageBytes: UInt64?,
                memoryLimitBytes: UInt64?,
                blockReadBytes: UInt64?,
                blockWriteBytes: UInt64?,
                networkRxBytes: UInt64?,
                networkTxBytes: UInt64?,
                numProcesses: UInt64?) {
        self.id = id
        self.cpuCoreFraction = cpuCoreFraction
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.blockReadBytes = blockReadBytes
        self.blockWriteBytes = blockWriteBytes
        self.networkRxBytes = networkRxBytes
        self.networkTxBytes = networkTxBytes
        self.numProcesses = numProcesses
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Metrics.RuntimeStatsSnapshot {
        Core.Metrics.RuntimeStatsSnapshot(id: runtimeKind.scopedID(for: id),
                                          cpuCoreFraction: cpuCoreFraction,
                                          memoryUsageBytes: memoryUsageBytes,
                                          memoryLimitBytes: memoryLimitBytes,
                                          blockReadBytes: blockReadBytes,
                                          blockWriteBytes: blockWriteBytes,
                                          networkRxBytes: networkRxBytes,
                                          networkTxBytes: networkTxBytes,
                                          numProcesses: numProcesses)
    }
}

/// A computed delta between two `Core.Metrics.ContainerStats` samples, the form the UI actually graphs.
struct StatsDelta: Sendable, Hashable {
    public let id: String
    /// CPU usage as a fraction of one core over the interval (can exceed 1.0 on multi-core load).
    public let cpuCoreFraction: Double
    public let memoryUsageBytes: UInt64
    public let memoryLimitBytes: UInt64
    public let netRxBytesPerSec: Double
    public let netTxBytesPerSec: Double
    public let blockReadBytesPerSec: Double
    public let blockWriteBytesPerSec: Double
    public let numProcesses: UInt64

    public var memoryFraction: Double {
        memoryLimitBytes > 0 ? Double(memoryUsageBytes) / Double(memoryLimitBytes) : 0
    }

    public init(id: String, cpuCoreFraction: Double, memoryUsageBytes: UInt64, memoryLimitBytes: UInt64,
                netRxBytesPerSec: Double, netTxBytesPerSec: Double, blockReadBytesPerSec: Double,
                blockWriteBytesPerSec: Double, numProcesses: UInt64) {
        self.id = id
        self.cpuCoreFraction = cpuCoreFraction
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.netRxBytesPerSec = netRxBytesPerSec
        self.netTxBytesPerSec = netTxBytesPerSec
        self.blockReadBytesPerSec = blockReadBytesPerSec
        self.blockWriteBytesPerSec = blockWriteBytesPerSec
        self.numProcesses = numProcesses
    }

    /// Deterministic sample values for previews and package examples.
    public static func sample(id: String = "preview") -> Core.Metrics.StatsDelta {
        Core.Metrics.StatsDelta(id: id, cpuCoreFraction: 0.42, memoryUsageBytes: 384_000_000, memoryLimitBytes: 1_073_741_824,
                   netRxBytesPerSec: 124_000, netTxBytesPerSec: 48_000, blockReadBytesPerSec: 0,
                   blockWriteBytesPerSec: 12_000, numProcesses: 7)
    }

    /// A smooth sample history for preview sparklines.
    public static var sampleHistory: [Double] {
        (0..<30).map { (i: Int) -> Double in
            let x = Double(i)
            let a: Double = sin(x / 3.0) * 0.22
            let b: Double = sin(x / 1.3) * 0.06
            return 0.42 + a + b
        }
    }

    /// Compute a delta from a previous sample taken `interval` seconds earlier.
    public static func between(previous: Core.Metrics.ContainerStats, current: Core.Metrics.ContainerStats, interval: TimeInterval) -> Core.Metrics.StatsDelta {
        let dt = max(interval, 0.001)
        func rate(_ a: UInt64?, _ b: UInt64?) -> Double {
            guard let a, let b, b >= a else { return 0 }
            return Double(b - a) / dt
        }
        // cpuUsageUsec is microseconds of CPU time; fraction of a core = Δusec / (dt * 1e6).
        let cpu: Double = {
            guard let a = previous.cpuUsageUsec, let b = current.cpuUsageUsec, b >= a else { return 0 }
            return Double(b - a) / (dt * 1_000_000)
        }()
        return Core.Metrics.StatsDelta(
            id: current.id,
            cpuCoreFraction: cpu,
            memoryUsageBytes: current.memoryUsageBytes ?? 0,
            memoryLimitBytes: current.memoryLimitBytes ?? 0,
            netRxBytesPerSec: rate(previous.networkRxBytes, current.networkRxBytes),
            netTxBytesPerSec: rate(previous.networkTxBytes, current.networkTxBytes),
            blockReadBytesPerSec: rate(previous.blockReadBytes, current.blockReadBytes),
            blockWriteBytesPerSec: rate(previous.blockWriteBytes, current.blockWriteBytes),
            numProcesses: current.numProcesses ?? 0
        )
    }

    /// Convert a streaming runtime snapshot into the UI delta shape.
    ///
    /// CPU is already a point-in-time fraction in streaming table/API sources. Throughput metrics
    /// are still cumulative counters, so they need the previous streamed snapshot and interval.
    public static func from(snapshot: Core.Metrics.RuntimeStatsSnapshot,
                            previous: Core.Metrics.RuntimeStatsSnapshot?,
                            interval: TimeInterval) -> Core.Metrics.StatsDelta {
        let dt = max(interval, 0.001)
        func rate(_ previous: UInt64?, _ current: UInt64?) -> Double {
            guard let previous, let current, current >= previous else { return 0 }
            return Double(current - previous) / dt
        }

        return Core.Metrics.StatsDelta(
            id: snapshot.id,
            cpuCoreFraction: snapshot.cpuCoreFraction ?? 0,
            memoryUsageBytes: snapshot.memoryUsageBytes ?? 0,
            memoryLimitBytes: snapshot.memoryLimitBytes ?? 0,
            netRxBytesPerSec: rate(previous?.networkRxBytes, snapshot.networkRxBytes),
            netTxBytesPerSec: rate(previous?.networkTxBytes, snapshot.networkTxBytes),
            blockReadBytesPerSec: rate(previous?.blockReadBytes, snapshot.blockReadBytes),
            blockWriteBytesPerSec: rate(previous?.blockWriteBytes, snapshot.blockWriteBytes),
            numProcesses: snapshot.numProcesses ?? 0
        )
    }
}

}
