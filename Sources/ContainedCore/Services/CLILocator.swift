import Foundation

/// Finds the `container` binary and reports its version. The app is not sandboxed, so it can read
/// these well-known install locations directly.
public enum CLILocator {
    public static let defaultCandidates = [
        "/usr/local/bin/container",
        "/opt/homebrew/bin/container",
    ]

    /// Resolve the CLI URL, honoring a user override first, then the standard locations.
    public static func locate(override: String? = nil,
                              candidates: [String] = defaultCandidates,
                              fileManager: FileManager = .default) -> URL? {
        if let override, !override.isEmpty, fileManager.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Parse the semantic version out of `container --version` output, e.g. "1.0.0".
    public static func parseVersion(_ output: String) -> String? {
        // Matches the first dotted numeric triple in a string like
        // "container CLI version 1.0.0 (build: release, commit: ee848e3)".
        guard let range = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) else { return nil }
        return String(output[range])
    }

    /// True when a version string is in the supported 1.0.x line.
    public static func isSupported(_ version: String?) -> Bool {
        guard let version else { return false }
        return version.hasPrefix("1.0.")
    }
}
