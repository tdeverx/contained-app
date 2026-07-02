import Foundation

public struct CoreSchemaVersion: Codable, Equatable, Hashable, Sendable {
    public var rawValue: Int

    public init(_ rawValue: Int = 1) {
        self.rawValue = rawValue
    }

    public static let current = CoreSchemaVersion()
}
