import Foundation

/// One Docker Hub repository search result.
public struct HubSearchResult: Decodable, Sendable, Identifiable, Hashable {
    public let repoName: String
    public let shortDescription: String?
    public let starCount: Int
    public let isOfficial: Bool
    public let isAutomated: Bool

    public var id: String { repoName }
    /// The reference to pull (Hub returns the canonical repo path for both official and user repos).
    public var pullReference: String { repoName }

    enum CodingKeys: String, CodingKey {
        case repoName = "repo_name"
        case shortDescription = "short_description"
        case starCount = "star_count"
        case isOfficial = "is_official"
        case isAutomated = "is_automated"
    }
}

/// The top-level shape of the Docker Hub search response.
public struct HubSearchResponse: Decodable, Sendable {
    public let results: [HubSearchResult]
}

/// Docker Hub search endpoint helpers. Pure URL building so the query shape is unit-testable; the
/// actual `URLSession` fetch lives in the app layer (no extra dependency).
public enum HubSearch {
    public static func url(query: String, pageSize: Int = 25) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: "https://hub.docker.com/v2/search/repositories/") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        return components.url
    }
}
