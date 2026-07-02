import Foundation

/// Stable identifier for a runtime adapter.
///
/// This is intentionally open-ended rather than a closed enum. Apple `container` is the first
/// adapter, Docker-compatible engines are an obvious future adapter, and the app should also be able
/// to host runtimes that do not exist yet without editing stored app state.
public struct RuntimeKind: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let appleContainer = RuntimeKind(rawValue: "apple-container")
    public static let dockerCompatible = RuntimeKind(rawValue: "docker-compatible")
}
