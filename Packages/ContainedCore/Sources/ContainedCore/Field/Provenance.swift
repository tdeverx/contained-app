import Foundation

public struct RuntimeFieldPath: Codable, Equatable, Hashable, Sendable {
    public var rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct RuntimeFieldProvenanceMap: Codable, Equatable, Sendable {
    public var fields: [RuntimeFieldPath: RuntimeKind]

    public init(fields: [RuntimeFieldPath: RuntimeKind] = [:]) {
        self.fields = fields
    }
}
