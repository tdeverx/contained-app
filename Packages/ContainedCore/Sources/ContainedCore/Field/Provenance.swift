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

    public init(fields: [Core.Field.Path: Core.Runtime.Kind] = [:]) {
        self.fields = fields
    }
}

}
