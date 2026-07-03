import Foundation

/// Finds a Docker CLI. V1 shells out to `docker` and does not manage Docker Desktop.
enum DockerCLILocator {
    static let defaultCandidates = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker",
    ]

    static func locate(override: String? = nil,
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

    static func parseVersion(_ output: String) -> String? {
        guard let range = output.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) else { return nil }
        return String(output[range])
    }
}
