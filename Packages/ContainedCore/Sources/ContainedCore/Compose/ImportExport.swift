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

    public init(items: [Core.Compose.ImportItem], warnings: [String] = []) {
        self.items = items
        self.warnings = warnings
    }
}

struct ImportItem: Equatable, Sendable {
    public var document: Core.Schema.Document
    public var healthCheck: Core.Container.HealthCheck?

    public init(document: Core.Schema.Document, healthCheck: Core.Container.HealthCheck? = nil) {
        self.document = document
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
