import Foundation

public enum ImageUpdateState: String, Sendable, Codable, Equatable {
    case unknown
    case checking
    case current
    case updateAvailable
    case error
}

public struct ImageUpdateStatus: Sendable, Codable, Equatable {
    public var state: ImageUpdateState
    public var localDigest: String?
    public var remoteDigest: String?
    public var checkedAt: Date?
    public var message: String?

    public init(state: ImageUpdateState = .unknown, localDigest: String? = nil,
                remoteDigest: String? = nil, checkedAt: Date? = nil, message: String? = nil) {
        self.state = state
        self.localDigest = localDigest
        self.remoteDigest = remoteDigest
        self.checkedAt = checkedAt
        self.message = message
    }

    public static func checking(localDigest: String?) -> ImageUpdateStatus {
        ImageUpdateStatus(state: .checking, localDigest: localDigest)
    }

    public static func resolved(localDigest: String?, remoteDigest: String, checkedAt: Date = Date()) -> ImageUpdateStatus {
        ImageUpdateStatus(
            state: localDigest == remoteDigest ? .current : .updateAvailable,
            localDigest: localDigest,
            remoteDigest: remoteDigest,
            checkedAt: checkedAt
        )
    }

    public static func failed(localDigest: String?, message: String, checkedAt: Date = Date()) -> ImageUpdateStatus {
        ImageUpdateStatus(state: .error, localDigest: localDigest, checkedAt: checkedAt, message: message)
    }
}
