import Foundation

/// How containers are ordered in the main grid.
enum ContainerSort: String, CaseIterable, Identifiable, Codable, Sendable {
    case name, status, created, uptime, image, runtime, cpu, memory, attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:      return AppText.string("filter.name", defaultValue: "Name")
        case .status:    return AppText.string("filter.status", defaultValue: "Status")
        case .created:   return AppText.string("filter.created", defaultValue: "Newest")
        case .uptime:    return AppText.string("filter.uptime", defaultValue: "Longest Running")
        case .image:     return AppText.string("filter.image", defaultValue: "Image")
        case .runtime:   return AppText.string("filter.runtime", defaultValue: "Runtime")
        case .cpu:       return AppText.string("filter.cpuUsage", defaultValue: "CPU Usage")
        case .memory:    return AppText.string("filter.memoryUsage", defaultValue: "Memory Usage")
        case .attention: return AppText.string("filter.needsAttention", defaultValue: "Needs Attention")
        }
    }

    var symbol: String {
        switch self {
        case .name:      return "textformat"
        case .status:    return "bolt"
        case .created:   return "calendar"
        case .uptime:    return "clock.arrow.circlepath"
        case .image:     return "shippingbox"
        case .runtime:   return "server.rack"
        case .cpu:       return "cpu"
        case .memory:    return "memorychip"
        case .attention: return "exclamationmark.triangle"
        }
    }

    var usesLiveMetrics: Bool { self == .cpu || self == .memory }
}
