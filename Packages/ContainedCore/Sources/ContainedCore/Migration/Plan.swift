import Foundation

public enum RuntimeCoreSwitchUnavailableReason: String, Equatable, Sendable {
    case exportImportUnsupported
}

public struct RuntimeCoreSwitchPlan: Equatable, Sendable {
    public var isAvailable: Bool
    public var unavailableReason: RuntimeCoreSwitchUnavailableReason?
    public var context: [String: String]
    public var source: RuntimeKind
    public var target: RuntimeKind?

    public init(isAvailable: Bool,
                unavailableReason: RuntimeCoreSwitchUnavailableReason?,
                context: [String: String] = [:],
                source: RuntimeKind,
                target: RuntimeKind?) {
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.context = context
        self.source = source
        self.target = target
    }
}
