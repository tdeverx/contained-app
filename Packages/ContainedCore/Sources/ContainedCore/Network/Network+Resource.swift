import Foundation

/// One element of `container network list --format json` (and `network inspect`).
public extension Core.Network {
struct Resource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: Core.Network.Configuration
    public let id: String
    public let status: Core.Network.Status?
    public let runtimeKind: Core.Runtime.Kind

    public var name: String { configuration.name }
    public var labels: [String: String] { configuration.labels }
    public var scopedID: String { runtimeKind.scopedID(for: id) }
    /// Networks Apple ships by default (e.g. `default`) carry a builtin resource-role label.
    public var isBuiltin: Bool { labels["com.apple.container.resource.role"] == "builtin" }

    public init(configuration: Core.Network.Configuration,
                id: String,
                status: Core.Network.Status?,
                runtimeKind: Core.Runtime.Kind) {
        self.configuration = configuration
        self.id = id
        self.status = status
        self.runtimeKind = runtimeKind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(Core.Network.Configuration.self, forKey: .configuration)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decodeIfPresent(Core.Network.Status.self, forKey: .status)
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

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Network.Resource {
        Core.Network.Resource(configuration: configuration, id: id, status: status, runtimeKind: runtimeKind)
    }
}

struct Configuration: Codable, Sendable, Hashable {
    public let name: String
    public let mode: String?
    public let plugin: String?
    public let creationDate: Date?
    public let labels: [String: String]
    public let options: Options?

    public struct Options: Codable, Sendable, Hashable {
        public let variant: String?
    }

    public init(name: String,
                mode: String? = nil,
                plugin: String? = nil,
                creationDate: Date? = nil,
                labels: [String: String] = [:],
                options: Options? = nil) {
        self.name = name
        self.mode = mode
        self.plugin = plugin
        self.creationDate = creationDate
        self.labels = labels
        self.options = options
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        plugin = try c.decodeIfPresent(String.self, forKey: .plugin)
        creationDate = try c.decodeIfPresent(Date.self, forKey: .creationDate)
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        options = try c.decodeIfPresent(Options.self, forKey: .options)
    }
}

struct Status: Codable, Sendable, Hashable {
    public let ipv4Gateway: String?
    public let ipv4Subnet: String?
    public let ipv6Subnet: String?
}

}
