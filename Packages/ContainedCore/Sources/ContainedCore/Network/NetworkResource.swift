import Foundation

/// One element of `container network list --format json` (and `network inspect`).
public struct NetworkResource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: NetworkConfiguration
    public let id: String
    public let status: NetworkStatus?

    public var name: String { configuration.name }
    public var labels: [String: String] { configuration.labels }
    /// Networks Apple ships by default (e.g. `default`) carry a builtin resource-role label.
    public var isBuiltin: Bool { labels["com.apple.container.resource.role"] == "builtin" }
}

public struct NetworkConfiguration: Codable, Sendable, Hashable {
    public let name: String
    public let mode: String?
    public let plugin: String?
    public let creationDate: Date?
    public let labels: [String: String]
    public let options: Options?

    public struct Options: Codable, Sendable, Hashable {
        public let variant: String?
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

public struct NetworkStatus: Codable, Sendable, Hashable {
    public let ipv4Gateway: String?
    public let ipv4Subnet: String?
    public let ipv6Subnet: String?
}
