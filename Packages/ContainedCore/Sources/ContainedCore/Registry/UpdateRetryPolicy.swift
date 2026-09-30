import Foundation

public extension Core.Registry {
    enum UpdateFailureKind: String, Codable, Sendable {
        case unauthorized, tokenUnavailable, rateLimited, network, notFound, invalidResponse

        public static func classify(_ error: Error) -> Self {
            if error is URLError { return .network }
            guard let manifest = error as? ManifestError else { return .invalidResponse }
            switch manifest {
            case .unauthorized: return .unauthorized
            case .tokenUnavailable: return .tokenUnavailable
            case .notFound: return .notFound
            case .httpStatus(429): return .rateLimited
            default: return .invalidResponse
            }
        }

        var bucket: String {
            switch self {
            case .unauthorized, .tokenUnavailable: return "authentication"
            default: return rawValue
            }
        }
    }

    /// Contains only resource identities, safe registry authorities, codes and retry timing.
    struct UpdateRetryPolicy: Codable, Sendable, Equatable {
        public struct Entry: Codable, Sendable, Equatable, Identifiable {
            public let id: String
            public let host: String
            public let runtimeKind: Core.Runtime.Kind
            public var kind: UpdateFailureKind
            public var attempts: Int
            public var retryAfter: Date
            public var references: [String]
        }

        public private(set) var entries: [String: Entry] = [:]
        public init() {}

        public static func host(for reference: String) -> String {
            guard !reference.contains("://") else { return "unknown" }
            let raw = ImageReference.parse(reference).registry.lowercased()
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_:[]")
            guard !raw.isEmpty, raw.unicodeScalars.allSatisfy(allowed.contains) else { return "unknown" }
            return raw == "registry-1.docker.io" ? "docker.io" : raw
        }

        public func shouldCheck(_ reference: String, runtimeKind: Core.Runtime.Kind,
                                now: Date = Date()) -> Bool {
            guard let normalized = Self.safeReference(reference) else { return false }
            let host = Self.host(for: reference)
            return !entries.values.contains {
                $0.host == host && $0.runtimeKind == runtimeKind && $0.retryAfter > now &&
                    ($0.references.contains(normalized) || $0.kind == .rateLimited || $0.kind == .network)
            }
        }

        /// Returns true once per changed failure episode, not once per tag or retry tick.
        @discardableResult
        public mutating func failed(_ reference: String, runtimeKind: Core.Runtime.Kind,
                                    kind: UpdateFailureKind, now: Date = Date()) -> Bool {
            guard let normalized = Self.safeReference(reference) else { return false }
            let host = Self.host(for: reference)
            let suffix = kind == .notFound ? normalized : kind.bucket
            let key = runtimeKind.scopedID(for: host + "|" + suffix)
            var entry = entries[key] ?? Entry(id: key, host: host, runtimeKind: runtimeKind,
                                              kind: kind, attempts: 0, retryAfter: now, references: [])
            let shouldLog = entries[key] == nil
            if entry.retryAfter <= now {
                entry.attempts = min(entry.attempts + 1, 8)
                entry.retryAfter = now.addingTimeInterval(min(21_600, 300 * pow(2, Double(entry.attempts - 1))))
            }
            entry.kind = kind
            if !entry.references.contains(normalized) {
                entry.references.append(normalized)
                entry.references.sort()
            }
            entries[key] = entry
            return shouldLog
        }

        public mutating func succeeded(_ reference: String, runtimeKind: Core.Runtime.Kind,
                                       authenticated: Bool) {
            guard let normalized = Self.safeReference(reference) else { return }
            let host = Self.host(for: reference)
            for (key, entry) in entries where entry.host == host && entry.runtimeKind == runtimeKind {
                if authenticated || entry.kind == .network || entry.kind == .rateLimited ||
                    entry.references == [normalized] {
                    entries.removeValue(forKey: key)
                } else if entry.references.contains(normalized) {
                    entries[key]?.references.removeAll { $0 == normalized }
                }
            }
        }

        public mutating func reset(host: String, runtimeKind: Core.Runtime.Kind) {
            let normalized = Self.host(for: host + "/placeholder")
            entries = entries.filter { $0.value.host != normalized || $0.value.runtimeKind != runtimeKind }
        }

        public mutating func reset(_ reference: String, runtimeKind: Core.Runtime.Kind) {
            reset(host: Self.host(for: reference), runtimeKind: runtimeKind)
        }

        /// Retry state accepts image identities, never arbitrary URLs/userinfo/query strings.
        private static func safeReference(_ reference: String) -> String? {
            let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:/@[]+")
            guard !trimmed.isEmpty, !trimmed.contains("://"),
                  trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
            let parsed = ImageReference.parse(trimmed)
            guard !parsed.repository.isEmpty, Self.host(for: trimmed) != "unknown",
                  let authority = URLComponents(string: "https://" + parsed.registry),
                  authority.host?.isEmpty == false, authority.url != nil,
                  authority.user == nil, authority.password == nil, authority.path.isEmpty,
                  authority.query == nil, authority.fragment == nil else { return nil }
            if parsed.isDigestReference {
                guard parsed.reference.range(of: "^[A-Za-z][A-Za-z0-9+._-]*:[A-Fa-f0-9]{32,}$", options: .regularExpression) != nil else { return nil }
            } else {
                guard parsed.reference.range(of: "^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", options: .regularExpression) != nil else { return nil }
            }
            return parsed.normalizedKey
        }
    }
}
