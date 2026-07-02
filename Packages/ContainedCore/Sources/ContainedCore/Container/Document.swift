import Foundation

public struct ContainerSpec: Codable, Equatable, Sendable {
    public var createRequest: ContainerCreateRequest

    public init(createRequest: ContainerCreateRequest = ContainerCreateRequest()) {
        self.createRequest = createRequest
    }
}

public struct RuntimeProjection: Codable, Equatable, Sendable {
    public var kind: RuntimeKind
    public var schemaVersion: CoreSchemaVersion
    public var preservedFields: [String: String]
    public var unsupportedFields: [String]

    public init(kind: RuntimeKind,
                schemaVersion: CoreSchemaVersion = .current,
                preservedFields: [String: String] = [:],
                unsupportedFields: [String] = []) {
        self.kind = kind
        self.schemaVersion = schemaVersion
        self.preservedFields = preservedFields
        self.unsupportedFields = unsupportedFields
    }
}

public struct ContainerDocument: Codable, Equatable, Sendable {
    public var canonical: ContainerSpec
    public var projections: [RuntimeKind: RuntimeProjection]
    public var provenance: RuntimeFieldProvenanceMap

    public init(canonical: ContainerSpec = ContainerSpec(),
                projections: [RuntimeKind: RuntimeProjection] = [:],
                provenance: RuntimeFieldProvenanceMap = RuntimeFieldProvenanceMap()) {
        self.canonical = canonical
        self.projections = projections
        self.provenance = provenance
    }
}
