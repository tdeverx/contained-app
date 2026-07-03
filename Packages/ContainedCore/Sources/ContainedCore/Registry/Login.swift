import Foundation

/// One entry from `registry list --format json`. The on-disk shape isn't documented (the list is
/// empty until you log in), so decode leniently across the likely key spellings for host/user.
public extension Core.Registry {
struct Login: Codable, Sendable, Identifiable, Hashable {
    public let host: String
    public let username: String?
    public let created: Date?
    public let modified: Date?
    public var runtimeKind: Core.Runtime.Kind

    public var id: String { runtimeKind.scopedID(for: host) }

    public init(host: String,
                username: String? = nil,
                created: Date? = nil,
                modified: Date? = nil,
                runtimeKind: Core.Runtime.Kind) {
        self.host = host
        self.username = username
        self.created = created
        self.modified = modified
        self.runtimeKind = runtimeKind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        func string(_ keys: [String]) -> String? {
            for k in keys {
                guard let key = DynamicCodingKey(stringValue: k) else { continue }
                if let v = try? c.decode(String.self, forKey: key) { return v }
            }
            return nil
        }
        func date(_ keys: [String]) -> Date? {
            for k in keys {
                guard let key = DynamicCodingKey(stringValue: k) else { continue }
                if let v = try? c.decode(Date.self, forKey: key) { return v }
            }
            return nil
        }
        host = string(["host", "hostname", "server", "registry"]) ?? "unknown"
        username = string(["username", "user"])
        created = date(["created", "createdAt", "creationDate"])
        modified = date(["modified", "modifiedAt", "updated"])
        if let runtimeKind = string(["runtimeKind"]).map(Core.Runtime.Kind.init(rawValue:)) {
            self.runtimeKind = runtimeKind
        } else if let contextRuntimeKind = decoder.coreRuntimeKindContext {
            runtimeKind = contextRuntimeKind
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Missing runtimeKind and no runtime decoding context was provided.")
            )
        }
    }

    public func scoped(to runtimeKind: Core.Runtime.Kind) -> Core.Registry.Login {
        Core.Registry.Login(host: host,
                            username: username,
                            created: created,
                            modified: modified,
                            runtimeKind: runtimeKind)
    }
}

}
