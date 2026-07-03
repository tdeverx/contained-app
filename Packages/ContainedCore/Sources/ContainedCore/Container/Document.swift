import Foundation

public extension Core.Container {
struct Spec: Codable, Equatable, Sendable {
    public var createRequest: Core.Container.CreateRequest

    public init(createRequest: Core.Container.CreateRequest = Core.Container.CreateRequest()) {
        self.createRequest = createRequest
    }
}

}

public extension Core.Runtime {
struct Projection: Codable, Equatable, Sendable {
    public var kind: Core.Runtime.Kind
    public var preservedFields: [String: String]
    public var unsupportedFields: [String]

    public init(kind: Core.Runtime.Kind,
                preservedFields: [String: String] = [:],
                unsupportedFields: [String] = []) {
        self.kind = kind
        self.preservedFields = preservedFields
        self.unsupportedFields = unsupportedFields
    }
}
}

public extension Core.Container {
struct Document: Codable, Equatable, Sendable {
    public var canonical: Core.Container.Spec
    public var projections: [Core.Runtime.Kind: Core.Runtime.Projection]
    public var provenance: Core.Field.ProvenanceMap

    public init(canonical: Core.Container.Spec = Core.Container.Spec(),
                projections: [Core.Runtime.Kind: Core.Runtime.Projection] = [:],
                provenance: Core.Field.ProvenanceMap = Core.Field.ProvenanceMap()) {
        self.canonical = canonical
        self.projections = projections
        self.provenance = provenance
    }
}

}
