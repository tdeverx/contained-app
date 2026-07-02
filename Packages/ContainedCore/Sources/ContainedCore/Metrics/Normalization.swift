import Foundation

public enum StatsNormalizationMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case container
    case machine = "global"

    public var id: String { rawValue }
}

public struct StatsNormalizationContext: Equatable, Sendable {
    public var mode: StatsNormalizationMode
    public var machineCPUs: Int?
    public var machineMemoryBytes: UInt64?

    public static let containerSpecific = StatsNormalizationContext(mode: .container)

    public init(mode: StatsNormalizationMode = .container,
                machineCPUs: Int? = nil,
                machineMemoryBytes: UInt64? = nil) {
        self.mode = mode
        self.machineCPUs = machineCPUs
        self.machineMemoryBytes = machineMemoryBytes
    }

    public func cpuLimit(for snapshot: ContainerSnapshot?) -> Double {
        switch mode {
        case .container:
            return max(Double(snapshot?.configuration.resources.cpus ?? 1), 1)
        case .machine:
            return max(Double(machineCPUs ?? ProcessInfo.processInfo.activeProcessorCount), 1)
        }
    }

    public func memoryLimitBytes(for snapshot: ContainerSnapshot?, fallback: UInt64 = 0) -> UInt64 {
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

    public func memoryLimitBytes(for delta: StatsDelta, snapshot: ContainerSnapshot?) -> UInt64 {
        memoryLimitBytes(for: snapshot, fallback: delta.memoryLimitBytes)
    }
}
