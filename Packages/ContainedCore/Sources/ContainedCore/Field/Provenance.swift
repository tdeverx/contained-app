import Foundation

public extension Core.Field {
struct Path: Codable, Equatable, Hashable, Sendable {
    public var rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

struct ProvenanceMap: Codable, Equatable, Sendable {
    public var fields: [Core.Field.Path: Core.Runtime.Kind]
    public var sources: [Core.Field.Path: Core.Schema.SourceKind]

    public init(fields: [Core.Field.Path: Core.Runtime.Kind] = [:],
                sources: [Core.Field.Path: Core.Schema.SourceKind] = [:]) {
        self.fields = fields
        self.sources = sources
    }

    private enum CodingKeys: String, CodingKey {
        case fields
        case sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decodeIfPresent([Core.Field.Path: Core.Runtime.Kind].self, forKey: .fields) ?? [:]
        sources = try container.decodeIfPresent([Core.Field.Path: Core.Schema.SourceKind].self, forKey: .sources) ?? [:]
    }
}

}
