import Foundation

/// One element of `container image inspect` (and the intended shape of `image list`, which can
/// currently fail wholesale when a single content blob is missing — see `Core.Command.Error`).
public extension Core.Image {
struct Resource: Codable, Sendable, Identifiable, Hashable {
    public let configuration: Core.Image.Configuration
    public let id: String
    public let variants: [Core.Image.Variant]
    public let runtimeKind: Core.Runtime.Kind

    public var reference: String { configuration.name }
    public var digest: String? { configuration.descriptor?.digest }
    public var scopedID: String { runtimeKind.scopedID(for: id) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(Core.Image.Configuration.self, forKey: .configuration)
        id = try c.decode(String.self, forKey: .id)
        variants = try c.decodeIfPresent([Core.Image.Variant].self, forKey: .variants) ?? []
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

    public init(configuration: Core.Image.Configuration,
                id: String,
                variants: [Core.Image.Variant] = [],
                runtimeKind: Core.Runtime.Kind) {
        self.configuration = configuration
        self.id = id
        self.variants = variants
        self.runtimeKind = runtimeKind
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Image.Resource {
        Core.Image.Resource(configuration: configuration,
                            id: id,
                            variants: variants,
                            runtimeKind: runtimeKind)
    }
}

struct Configuration: Codable, Sendable, Hashable {
    public let name: String
    public let descriptor: Core.Container.Descriptor?
    public let creationDate: Date?
}

/// A per-platform variant within a (usually multi-arch) image index.
struct Variant: Codable, Sendable, Hashable, Identifiable {
    public let digest: String
    public let size: Int?
    public let platform: Core.Container.Platform
    public let config: Core.Image.VariantConfig?

    public var id: String { digest }
    /// "unknown/unknown" variants are attestation/SBOM blobs, not runnable images.
    public var isRunnable: Bool { platform.os != "unknown" && platform.architecture != "unknown" }
}

struct VariantConfig: Codable, Sendable, Hashable {
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

}
