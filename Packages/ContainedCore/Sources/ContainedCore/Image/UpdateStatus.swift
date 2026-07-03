import Foundation

public extension Core.Image {
enum UpdateState: String, Sendable, Codable, Equatable {
    case unknown
    case checking
    case current
    case updateAvailable
    case error
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
