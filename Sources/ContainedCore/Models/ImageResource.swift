import Foundation

/// One element of `container image inspect` (and the intended shape of `image list`, which can
/// currently fail wholesale when a single content blob is missing — see `CommandError`).
public struct ImageResource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: ImageConfiguration
    public let id: String
    public let variants: [ImageVariant]

    public var reference: String { configuration.name }
    public var digest: String? { configuration.descriptor?.digest }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(ImageConfiguration.self, forKey: .configuration)
        id = try c.decode(String.self, forKey: .id)
        variants = try c.decodeIfPresent([ImageVariant].self, forKey: .variants) ?? []
    }
}

public struct ImageConfiguration: Codable, Sendable, Hashable {
    public let name: String
    public let descriptor: Descriptor?
    public let creationDate: Date?
}

/// A per-platform variant within a (usually multi-arch) image index.
public struct ImageVariant: Codable, Sendable, Hashable, Identifiable {
    public let digest: String
    public let size: Int?
    public let platform: Platform
    public let config: VariantConfig?

    public var id: String { digest }
    /// "unknown/unknown" variants are attestation/SBOM blobs, not runnable images.
    public var isRunnable: Bool { platform.os != "unknown" && platform.architecture != "unknown" }
}

public struct VariantConfig: Codable, Sendable, Hashable {
    public let architecture: String?
    public let os: String?
    public let created: Date?
    public let config: OCIConfig?
    public let history: [HistoryEntry]?
    public let rootfs: RootFS?

    public struct OCIConfig: Codable, Sendable, Hashable {
        public let cmd: [String]?
        public let entrypoint: [String]?
        public let env: [String]?
        public let workingDir: String?
        public let user: String?

        enum CodingKeys: String, CodingKey {
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case env = "Env"
            case workingDir = "WorkingDir"
            case user = "User"
        }
    }

    public struct HistoryEntry: Codable, Sendable, Hashable {
        public let created: Date?
        public let createdBy: String?
        public let comment: String?
        public let emptyLayer: Bool?

        enum CodingKeys: String, CodingKey {
            case created
            case createdBy = "created_by"
            case comment
            case emptyLayer = "empty_layer"
        }
    }

    public struct RootFS: Codable, Sendable, Hashable {
        public let type: String?
        public let diffIDs: [String]?

        enum CodingKeys: String, CodingKey {
            case type
            case diffIDs = "diff_ids"
        }
    }
}
