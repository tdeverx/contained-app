import Foundation

public extension Core.Migration {
enum UnavailableReason: String, Equatable, Sendable {
    case exportImportUnsupported
}

struct Plan: Equatable, Sendable {
    public var isAvailable: Bool
    public var unavailableReason: Core.Migration.UnavailableReason?
    public var context: [String: String]
    public var source: Core.Runtime.Kind
    public var target: Core.Runtime.Kind?

    public init(isAvailable: Bool,
                unavailableReason: Core.Migration.UnavailableReason?,
                context: [String: String] = [:],
                source: Core.Runtime.Kind,
                target: Core.Runtime.Kind?) {
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.context = context
        self.source = source
        self.target = target
    }
}

}
