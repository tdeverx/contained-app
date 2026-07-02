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
    public var pullReference: String {
        guard isOfficial, repoName.hasPrefix("library/") else { return repoName }
        return String(repoName.dropFirst("library/".count))
    }

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

/// Docker Hub search endpoint helpers. Centralizes URL construction, response validation, and
/// decoding so toolbar search and the full image picker cannot drift.
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

    public static func results(query: String,
                               pageSize: Int = 25,
                               session: URLSession = .shared) async throws -> [HubSearchResult] {
        guard let url = url(query: query, pageSize: pageSize) else { return [] }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(HubSearchResponse.self, from: data).results
    }
}
