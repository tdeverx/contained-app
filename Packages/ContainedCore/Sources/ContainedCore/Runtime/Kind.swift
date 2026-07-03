import Foundation

/// Stable identifier for a runtime adapter.
///
/// This is intentionally open-ended rather than a closed enum. Apple `container` is one
/// adapter, Docker is another, and the app should also be able to host runtimes that do not
/// exist yet without editing stored app state.
public extension Core.Runtime {
    struct Kind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let appleContainer = Kind(rawValue: "apple-container")
        public static let docker = Kind(rawValue: "docker")

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.init(rawValue: try container.decode(String.self))
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public func scopedID(for id: String) -> String {
            "\(rawValue)::\(id)"
        }

        public static func parseScopedID(_ scopedID: String) -> (kind: Core.Runtime.Kind, id: String)? {
            guard let separator = scopedID.range(of: "::") else { return nil }
            let rawKind = String(scopedID[..<separator.lowerBound])
            let id = String(scopedID[separator.upperBound...])
            guard !rawKind.isEmpty, !id.isEmpty else { return nil }
            return (Core.Runtime.Kind(rawValue: rawKind), id)
        }
    }
}

public extension Core.Runtime {
    static func scopedID(kind: Core.Runtime.Kind, id: String) -> String {
        kind.scopedID(for: id)
    }
}
