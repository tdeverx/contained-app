import Foundation

public extension Core.Runtime {
struct Configuration: Sendable, Equatable {
    public var cliPathOverride: String?

    public init(cliPathOverride: String? = nil) {
        self.cliPathOverride = cliPathOverride
    }
}
}
