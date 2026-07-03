import Foundation

public extension Core.Command {
struct Preview: Equatable, Sendable {
    public var command: [String]
    public var warnings: [String]

    public init(command: [String], warnings: [String] = []) {
        self.command = command
        self.warnings = warnings
    }
}

struct Invocation: Equatable, Sendable {
    public var executableURL: URL
    public var arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}

}
