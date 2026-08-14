import Foundation
import ContainedCore

/// Resolves the local web destination shown by a container card.
enum ContainerWebDestination {
    static func url(customValue: String, for snapshot: Core.Container.Snapshot) -> URL? {
        normalizedCustomURL(customValue) ?? inferredURL(for: snapshot)
    }

    static func inferredURL(for snapshot: Core.Container.Snapshot) -> URL? {
        guard let port = snapshot.configuration.publishedPorts.first(where: {
            ($0.proto ?? "tcp").lowercased() == "tcp" && $0.hostPort > 0
        }) else { return nil }

        var components = URLComponents()
        components.scheme = port.hostPort == 443 ? "https" : "http"
        components.host = browserHost(port.hostAddress)
        components.port = port.hostPort
        return components.url
    }

    private static func normalizedCustomURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false else { return nil }
        return components.url
    }

    private static func browserHost(_ hostAddress: String?) -> String {
        guard let hostAddress,
              !hostAddress.isEmpty,
              hostAddress != "0.0.0.0",
              hostAddress != "::",
              hostAddress != "[::]" else { return "localhost" }
        return hostAddress
    }
}
