import Foundation

public extension Core.Runtime {
struct Capability: OptionSet, Equatable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let containers = Core.Runtime.Capability(rawValue: 1 << 0)
    public static let images = Core.Runtime.Capability(rawValue: 1 << 1)
    public static let imageBuild = Core.Runtime.Capability(rawValue: 1 << 2)
    public static let imagePush = Core.Runtime.Capability(rawValue: 1 << 3)
    public static let imageArchive = Core.Runtime.Capability(rawValue: 1 << 4)
    public static let registries = Core.Runtime.Capability(rawValue: 1 << 5)
    public static let networks = Core.Runtime.Capability(rawValue: 1 << 6)
    public static let volumes = Core.Runtime.Capability(rawValue: 1 << 7)
    public static let systemStatus = Core.Runtime.Capability(rawValue: 1 << 8)
    public static let systemLogs = Core.Runtime.Capability(rawValue: 1 << 9)
    public static let systemProperties = Core.Runtime.Capability(rawValue: 1 << 10)
    public static let dnsManagement = Core.Runtime.Capability(rawValue: 1 << 11)
    public static let kernelManagement = Core.Runtime.Capability(rawValue: 1 << 12)
    public static let exec = Core.Runtime.Capability(rawValue: 1 << 13)
    public static let copy = Core.Runtime.Capability(rawValue: 1 << 14)
    public static let containerExport = Core.Runtime.Capability(rawValue: 1 << 15)
    public static let composeImport = Core.Runtime.Capability(rawValue: 1 << 16)
    public static let coreMigration = Core.Runtime.Capability(rawValue: 1 << 17)
    public static let serviceControl = Core.Runtime.Capability(rawValue: 1 << 18)
}
}
