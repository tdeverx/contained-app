import Foundation

/// One entry from `registry list --format json`. The on-disk shape isn't documented (the list is
/// empty until you log in), so decode leniently across the likely key spellings for host/user.
public struct RegistryLogin: Codable, Sendable, Identifiable, Hashable {
    public let host: String
    public let username: String?
    public let created: Date?
    public let modified: Date?

    public var id: String { host }

    public init(host: String, username: String? = nil, created: Date? = nil, modified: Date? = nil) {
        self.host = host; self.username = username; self.created = created; self.modified = modified
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
    }
}
