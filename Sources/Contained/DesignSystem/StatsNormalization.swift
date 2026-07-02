import Foundation
import ContainedCore

enum StatsNormalizationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case container
    case machine = "global"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .container: return "Container"
        case .machine: return "Machine"
        }
    }

    var footnote: String {
        switch self {
        case .container:
            return "CPU and memory are scaled against each container's own configured limits."
        case .machine:
            return "CPU and memory are scaled against Apple container's machine CPU and memory resources."
        }
    }
}

struct StatsNormalizationContext: Equatable, Sendable {
    var mode: StatsNormalizationMode = .container
    var machineCPUs: Int?
    var machineMemoryBytes: UInt64?

    static let containerSpecific = StatsNormalizationContext(mode: .container)

    func cpuLimit(for snapshot: ContainerSnapshot?) -> Double {
        switch mode {
        case .container:
            return max(Double(snapshot?.configuration.resources.cpus ?? 1), 1)
        case .machine:
            return max(Double(machineCPUs ?? ProcessInfo.processInfo.activeProcessorCount), 1)
        }
    }

    func memoryLimitBytes(for snapshot: ContainerSnapshot?, fallback: UInt64 = 0) -> UInt64 {
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

    func memoryLimitBytes(for delta: StatsDelta, snapshot: ContainerSnapshot?) -> UInt64 {
        memoryLimitBytes(for: snapshot, fallback: delta.memoryLimitBytes)
    }
}
