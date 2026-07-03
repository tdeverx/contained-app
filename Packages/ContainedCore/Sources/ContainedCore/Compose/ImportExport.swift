import Foundation

public extension Core.Compose {
enum Dialect: String, Codable, Equatable, Hashable, Sendable {
    case generic
    case dockerCompose
    case podmanCompose
    case nerdctlCompose
}

struct ImportPlan: Equatable, Sendable {
    public var items: [Core.Compose.ImportItem]
    public var warnings: [String]

    public init(requests: [Core.Container.CreateRequest], warnings: [String] = []) {
        self.items = requests.map { Core.Compose.ImportItem(request: $0) }
        self.warnings = warnings
    }

    public init(items: [Core.Compose.ImportItem], warnings: [String] = []) {
        self.items = items
        self.warnings = warnings
    }

    public var requests: [Core.Container.CreateRequest] {
        items.map(\.request)
    }
}

struct ImportItem: Equatable, Sendable {
    public var request: Core.Container.CreateRequest
    public var healthCheck: Core.Container.HealthCheck?

    public init(request: Core.Container.CreateRequest, healthCheck: Core.Container.HealthCheck? = nil) {
        self.request = request
        self.healthCheck = healthCheck
    }
}

struct ExportPlan: Equatable, Sendable {
    public var dialect: Core.Compose.Dialect
    public var warnings: [String]
    public var isAvailable: Bool

    public init(dialect: Core.Compose.Dialect = .generic,
                warnings: [String] = [],
                isAvailable: Bool = false) {
        self.dialect = dialect
        self.warnings = warnings
        self.isAvailable = isAvailable
    }
}

}
