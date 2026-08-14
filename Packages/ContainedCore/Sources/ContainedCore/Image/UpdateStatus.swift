import Foundation

public extension Core.Image {
enum UpdateState: String, Sendable, Codable, Equatable {
    case unknown
    case checking
    case current
    case updateAvailable
    case error
}

/// Whether a container's immutable image identity still matches the image currently behind its tag.
enum ContainerUpdateState: String, Sendable, Codable, Equatable {
    case unknown
    case current
    case updateAvailable
    case updateReady

    public var requiresUpdate: Bool {
        self == .updateAvailable || self == .updateReady
    }

    public var needsPull: Bool { self == .updateAvailable }

    /// Resolve remote availability before the local identity comparison. When another remote update
    /// exists after a previous pull, applying should pull that newest image before recreating.
    public static func resolve(containerIdentity: String?,
                               localIdentities: [String],
                               trackedStatus: Core.Image.UpdateStatus) -> Core.Image.ContainerUpdateState {
        if trackedStatus.state == .updateAvailable { return .updateAvailable }
        guard let containerIdentity,
              !containerIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !localIdentities.isEmpty else {
            return .unknown
        }
        let containerKey = normalizedContentIdentity(containerIdentity)
        let matchesCurrentImage = localIdentities.contains {
            normalizedContentIdentity($0) == containerKey
        }
        return matchesCurrentImage ? .current : .updateReady
    }

    private static func normalizedContentIdentity(_ value: String) -> String {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return key.hasPrefix("sha256:") ? String(key.dropFirst("sha256:".count)) : key
    }
}

struct UpdateStatus: Sendable, Codable, Equatable {
    public var state: Core.Image.UpdateState
    public var localDigest: String?
    public var remoteDigest: String?
    public var checkedAt: Date?
    public var message: String?

    public init(state: Core.Image.UpdateState = .unknown, localDigest: String? = nil,
                remoteDigest: String? = nil, checkedAt: Date? = nil, message: String? = nil) {
        self.state = state
        self.localDigest = localDigest
        self.remoteDigest = remoteDigest
        self.checkedAt = checkedAt
        self.message = message
    }

    public static func checking(localDigest: String?) -> Core.Image.UpdateStatus {
        Core.Image.UpdateStatus(state: .checking, localDigest: localDigest)
    }

    public static func resolved(localDigest: String?, remoteDigest: String, checkedAt: Date = Date()) -> Core.Image.UpdateStatus {
        Core.Image.UpdateStatus(
            state: localDigest == remoteDigest ? .current : .updateAvailable,
            localDigest: localDigest,
            remoteDigest: remoteDigest,
            checkedAt: checkedAt
        )
    }

    public static func failed(localDigest: String?, message: String, checkedAt: Date = Date()) -> Core.Image.UpdateStatus {
        Core.Image.UpdateStatus(state: .error, localDigest: localDigest, checkedAt: checkedAt, message: message)
    }
}

}
