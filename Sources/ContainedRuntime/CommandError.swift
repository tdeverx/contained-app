import Foundation

/// A typed error for everything that can go wrong invoking the `container` CLI.
public enum CommandError: Error, Sendable, Equatable {
    /// The `container` binary could not be located on disk.
    case cliNotFound(searched: [String])
    /// The process launched but exited non-zero. `stderr` is the trimmed error text.
    case nonZeroExit(code: Int32, stderr: String, command: String)
    /// The process produced output that failed to decode as the expected JSON.
    case decodingFailed(underlying: String, command: String)
    /// The process could not be launched at all.
    case launchFailed(underlying: String)

    /// A short, user-facing message suitable for a toast.
    public var userMessage: String {
        switch self {
        case .cliNotFound(let searched):
            return "Couldn't find the container CLI (looked in \(searched.joined(separator: ", "))."
        case .nonZeroExit(_, let stderr, _):
            return stderr.isEmpty ? "The container command failed." : stderr
        case .decodingFailed:
            return "Couldn't read the response from the container CLI."
        case .launchFailed(let underlying):
            return "Couldn't run the container CLI: \(underlying)"
        }
    }
}
