import Foundation

/// `system property list --format json` — the daemon's default configuration (builder + default
/// container resources + kernel). Decoded leniently; unknown/empty sections are tolerated.
public struct SystemProperties: Codable, Sendable, Hashable {
    public let build: Build?
    public let container: Defaults?
    public let kernel: Kernel?

    public struct Build: Codable, Sendable, Hashable {
        public let cpus: Int?
        public let memory: String?
        public let image: String?
        public let rosetta: Bool?
    }
    public struct Defaults: Codable, Sendable, Hashable {
        public let cpus: Int?
        public let memory: String?
    }
    public struct Kernel: Codable, Sendable, Hashable {
        public let binaryPath: String?
        public let url: String?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        build = try c.decodeIfPresent(Build.self, forKey: .build)
        container = try c.decodeIfPresent(Defaults.self, forKey: .container)
        kernel = try c.decodeIfPresent(Kernel.self, forKey: .kernel)
    }
}
