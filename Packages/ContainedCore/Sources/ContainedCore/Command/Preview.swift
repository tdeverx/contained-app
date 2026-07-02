import Foundation

public struct RuntimeCommandPreview: Equatable, Sendable {
    public var command: [String]
    public var warnings: [String]

    public init(command: [String], warnings: [String] = []) {
        self.command = command
        self.warnings = warnings
    }
}

public struct CommandInvocation: Equatable, Sendable {
    public var executableURL: URL
    public var arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}
