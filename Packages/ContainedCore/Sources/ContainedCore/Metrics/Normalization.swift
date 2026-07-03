import Foundation

public extension Core.Metrics {
enum NormalizationMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case container
    case machine = "global"

    public var id: String { rawValue }
}

struct NormalizationContext: Equatable, Sendable {
    public var mode: Core.Metrics.NormalizationMode
    public var machineCPUs: Int?
    public var machineMemoryBytes: UInt64?

    public static let containerSpecific = Core.Metrics.NormalizationContext(mode: .container)

    public init(mode: Core.Metrics.NormalizationMode = .container,
                machineCPUs: Int? = nil,
                machineMemoryBytes: UInt64? = nil) {
        self.mode = mode
        self.machineCPUs = machineCPUs
        self.machineMemoryBytes = machineMemoryBytes
    }

    public func cpuLimit(for snapshot: Core.Container.Snapshot?) -> Double {
        switch mode {
        case .container:
            return max(Double(snapshot?.configuration.resources.cpus ?? 1), 1)
        case .machine:
            return max(Double(machineCPUs ?? ProcessInfo.processInfo.activeProcessorCount), 1)
        }
    }

    public func memoryLimitBytes(for snapshot: Core.Container.Snapshot?, fallback: UInt64 = 0) -> UInt64 {
        switch mode {
        case .container:
            let configuredLimit = snapshot?.configuration.resources.memoryInBytes ?? 0
            return configuredLimit > 0 ? configuredLimit : fallback
        case .machine:
            let machineMemory = machineMemoryBytes ?? ProcessInfo.processInfo.physicalMemory
            if machineMemory > 0 { return machineMemory }
            let configuredLimit = snapshot?.configuration.resources.memoryInBytes ?? 0
            return configuredLimit > 0 ? configuredLimit : fallback
        }
    }

    public func memoryLimitBytes(for delta: Core.Metrics.StatsDelta, snapshot: Core.Container.Snapshot?) -> UInt64 {
        memoryLimitBytes(for: snapshot, fallback: delta.memoryLimitBytes)
    }
}

}
