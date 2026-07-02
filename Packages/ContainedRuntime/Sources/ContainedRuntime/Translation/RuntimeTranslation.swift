import Foundation
import ContainedCore

public struct RuntimeCommandPreview: Equatable, Sendable {
    public var command: [String]
    public var warnings: [String]

    public init(command: [String], warnings: [String] = []) {
        self.command = command
        self.warnings = warnings
    }
}

public struct RuntimeComposeImportPlan: Equatable, Sendable {
    public var items: [RuntimeComposeImportItem]
    public var warnings: [String]

    public init(requests: [ContainerCreateRequest], warnings: [String] = []) {
        self.items = requests.map { RuntimeComposeImportItem(request: $0) }
        self.warnings = warnings
    }

    public init(items: [RuntimeComposeImportItem], warnings: [String] = []) {
        self.items = items
        self.warnings = warnings
    }

    public var requests: [ContainerCreateRequest] {
        items.map(\.request)
    }
}

public struct RuntimeComposeImportItem: Equatable, Sendable {
    public var request: ContainerCreateRequest
    public var healthCheck: HealthCheck?

    public init(request: ContainerCreateRequest, healthCheck: HealthCheck? = nil) {
        self.request = request
        self.healthCheck = healthCheck
    }
}

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
