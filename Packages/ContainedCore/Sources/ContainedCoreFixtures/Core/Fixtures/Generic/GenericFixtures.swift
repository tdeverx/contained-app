import Foundation
import ContainedCore

public extension Core.Fixtures.Generic {
    struct MetricHistory: Equatable, Sendable, ContainedCore.MetricHistorySample {
        public var timestamp: Date
        public var cpuFraction: Double
        public var memoryBytes: Double
        public var netRxBytesPerSec: Double
        public var netTxBytesPerSec: Double
        public var diskReadBytesPerSec: Double
        public var diskWriteBytesPerSec: Double

        public init(timestamp: Date,
                    cpuFraction: Double,
                    memoryBytes: Double,
                    netRxBytesPerSec: Double,
                    netTxBytesPerSec: Double,
                    diskReadBytesPerSec: Double,
                    diskWriteBytesPerSec: Double) {
            self.timestamp = timestamp
            self.cpuFraction = cpuFraction
            self.memoryBytes = memoryBytes
            self.netRxBytesPerSec = netRxBytesPerSec
            self.netTxBytesPerSec = netTxBytesPerSec
            self.diskReadBytesPerSec = diskReadBytesPerSec
            self.diskWriteBytesPerSec = diskWriteBytesPerSec
        }
    }

    static let now = Date(timeIntervalSinceReferenceDate: 790_000_000)

    static let sparklineValues: [Double] = [
        0.12, 0.16, 0.18, 0.25, 0.22, 0.31, 0.38, 0.35,
        0.44, 0.48, 0.43, 0.52, 0.57, 0.54, 0.61, 0.58,
        0.66, 0.62, 0.70, 0.68, 0.74, 0.71, 0.78, 0.76,
    ]

    static let networkSamples: [Double] = [
        18_000, 24_000, 22_000, 46_000, 42_000, 54_000,
        66_000, 72_000, 68_000, 80_000, 92_000, 88_000,
    ]

    static let metricHistory: [MetricHistory] = sparklineValues.enumerated().map { offset, value in
        MetricHistory(
            timestamp: now.addingTimeInterval(Double(offset) * 30),
            cpuFraction: value,
            memoryBytes: 260_000_000 + Double(offset) * 6_000_000,
            netRxBytesPerSec: networkSamples[offset % networkSamples.count],
            netTxBytesPerSec: networkSamples[(offset + 3) % networkSamples.count] * 0.45,
            diskReadBytesPerSec: 4_000 + Double(offset * 320),
            diskWriteBytesPerSec: 8_000 + Double(offset * 420)
        )
    }
}
