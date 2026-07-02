import Foundation

public struct RegistryImageReference: Sendable, Hashable {
    public let original: String
    public let registry: String
    public let repository: String
    public let reference: String
    public let isDigestReference: Bool

    public var manifestURL: URL {
        URL(string: "https://\(registry)/v2/\(repository)/manifests/\(reference)")!
    }

    public var authScope: String { "repository:\(repository):pull" }

    public var normalizedKey: String {
        let displayRegistry = registry == "registry-1.docker.io" ? "docker.io" : registry
        let separator = isDigestReference ? "@" : ":"
        return "\(displayRegistry)/\(repository)\(separator)\(reference)"
    }

    public static func parse(_ raw: String) -> RegistryImageReference {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digestSplit = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let namePart = String(digestSplit.first ?? "")
        let explicitDigest = digestSplit.count == 2 ? String(digestSplit[1]) : nil

        let parts = namePart.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let first = parts.first ?? ""
        let hasRegistry = first.contains(".") || first.contains(":") || first == "localhost"
        let rawRegistry = hasRegistry ? first : "docker.io"
        var repositoryParts = hasRegistry ? Array(parts.dropFirst()) : parts
        if repositoryParts.count == 1, rawRegistry == "docker.io" || rawRegistry == "index.docker.io" {
            repositoryParts.insert("library", at: 0)
        }

        var repository = repositoryParts.joined(separator: "/")
        var reference = "latest"
        var isDigest = false

        if let explicitDigest {
            reference = explicitDigest
            isDigest = true
        } else if let lastSlash = repository.lastIndex(of: "/") {
            let tail = repository[repository.index(after: lastSlash)...]
            if let colon = tail.lastIndex(of: ":") {
                let absoluteColon = tail[colon...].startIndex
                reference = String(repository[repository.index(after: absoluteColon)...])
                repository = String(repository[..<absoluteColon])
            }
        } else if let colon = repository.lastIndex(of: ":") {
            reference = String(repository[repository.index(after: colon)...])
            repository = String(repository[..<colon])
        }

        let registry: String
        switch rawRegistry {
        case "docker.io", "index.docker.io":
            registry = "registry-1.docker.io"
        default:
            registry = rawRegistry
        }

        return RegistryImageReference(
            original: trimmed,
            registry: registry,
            repository: repository,
            reference: reference,
            isDigestReference: isDigest
        )
    }

    public static func normalizedKey(_ raw: String) -> String {
        parse(raw).normalizedKey
    }
}
