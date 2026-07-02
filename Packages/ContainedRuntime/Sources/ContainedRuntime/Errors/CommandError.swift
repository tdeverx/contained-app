import Foundation
import ContainedCore

/// A typed error for everything that can go wrong invoking the `container` CLI.
public enum CommandError: ContainedPackageError, Equatable {
    /// The `container` binary could not be located on disk.
    case cliNotFound(searched: [String])
    /// The process launched but exited non-zero. `stderr` is the trimmed error text.
    case nonZeroExit(code: Int32, stderr: String, command: String)
    /// The process produced output that failed to decode as the expected JSON.
    case decodingFailed(underlying: String, command: String)
    /// The process could not be launched at all.
    case launchFailed(underlying: String)

    public var packageName: String { "ContainedRuntime" }

    public var packageErrorCode: String {
        switch self {
        case .cliNotFound: return "cliNotFound"
        case .nonZeroExit: return "nonZeroExit"
        case .decodingFailed: return "decodingFailed"
        case .launchFailed: return "launchFailed"
        }
    }

    public var packageErrorContext: [String: String] {
        switch self {
        case .cliNotFound(let searched):
            return ["searched": searched.joined(separator: ", ")]
        case .nonZeroExit(let code, let stderr, let command):
            return ["code": String(code), "stderr": stderr, "command": command]
        case .decodingFailed(let underlying, let command):
            return ["underlying": underlying, "command": command]
        case .launchFailed(let underlying):
            return ["underlying": underlying]
        }
    }
}
