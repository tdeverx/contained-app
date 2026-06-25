import Foundation

/// One element of `container volume list --format json`.
///
/// The local environment has no volumes yet (fixture is `[]`), so this is modeled leniently from
/// the `apple/container` source layout (`configuration` + computed `name`/`labels`). Fields are
/// confirmed/expanded once a real volume fixture is captured.
public struct VolumeResource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: VolumeConfiguration
    public var id: String { configuration.name }
    public var name: String { configuration.name }
    public var labels: [String: String] { configuration.labels }
}

public struct VolumeConfiguration: Codable, Sendable, Hashable {
    public let name: String
    public let source: String?
    public let format: String?
    public let sizeInBytes: UInt64?
    public let creationDate: Date?
    public let labels: [String: String]

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
