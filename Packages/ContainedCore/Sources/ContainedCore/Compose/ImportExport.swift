import Foundation

public enum ComposeDialect: String, Codable, Equatable, Hashable, Sendable {
    case generic
    case dockerCompose
    case podmanCompose
    case nerdctlCompose
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

public struct ComposeExportPlan: Equatable, Sendable {
    public var dialect: ComposeDialect
    public var warnings: [String]
    public var isAvailable: Bool

    public init(dialect: ComposeDialect = .generic,
                warnings: [String] = [],
                isAvailable: Bool = false) {
        self.dialect = dialect
        self.warnings = warnings
        self.isAvailable = isAvailable
    }
}
