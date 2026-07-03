import Foundation

public extension Core.Schema {
struct Version: Codable, Equatable, Hashable, Sendable {
    public var rawValue: Int

    public init(_ rawValue: Int = 1) {
        self.rawValue = rawValue
    }

    public static let current = Core.Schema.Version()
}

}
