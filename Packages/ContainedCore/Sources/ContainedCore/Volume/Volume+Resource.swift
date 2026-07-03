import Foundation

/// One element of `container volume list --format json`.
///
/// The local environment has no volumes yet (fixture is `[]`), so this is modeled leniently from
/// the `apple/container` source layout (`configuration` + computed `name`/`labels`). Fields are
/// confirmed/expanded once a real volume fixture is captured.
public extension Core.Volume {
struct Resource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: Core.Volume.Configuration
    public let runtimeKind: Core.Runtime.Kind
    public var id: String { configuration.name }
    public var name: String { configuration.name }
    public var labels: [String: String] { configuration.labels }
    public var scopedID: String { runtimeKind.scopedID(for: id) }

    public init(configuration: Core.Volume.Configuration,
                runtimeKind: Core.Runtime.Kind) {
        self.configuration = configuration
        self.runtimeKind = runtimeKind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(Core.Volume.Configuration.self, forKey: .configuration)
        if let decodedRuntimeKind = try c.decodeIfPresent(Core.Runtime.Kind.self, forKey: .runtimeKind) {
            runtimeKind = decodedRuntimeKind
        } else if let contextRuntimeKind = decoder.coreRuntimeKindContext {
            runtimeKind = contextRuntimeKind
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.runtimeKind,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Missing runtimeKind and no runtime decoding context was provided.")
            )
        }
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Volume.Resource {
        Core.Volume.Resource(configuration: configuration, runtimeKind: runtimeKind)
    }
}

struct Configuration: Codable, Sendable, Hashable {
    public let name: String
    public let source: String?
    public let format: String?
    public let sizeInBytes: UInt64?
    public let creationDate: Date?
    public let labels: [String: String]

    public init(name: String,
                source: String? = nil,
                format: String? = nil,
                sizeInBytes: UInt64? = nil,
                creationDate: Date? = nil,
                labels: [String: String] = [:]) {
        self.name = name
        self.source = source
        self.format = format
        self.sizeInBytes = sizeInBytes
        self.creationDate = creationDate
        self.labels = labels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        format = try c.decodeIfPresent(String.self, forKey: .format)
        sizeInBytes = try c.decodeIfPresent(UInt64.self, forKey: .sizeInBytes)
        creationDate = try c.decodeIfPresent(Date.self, forKey: .creationDate)
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }
}

}
