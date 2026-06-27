import Foundation

public enum RegistryManifestError: Error, LocalizedError, Equatable {
    case invalidResponse
    case unauthorized
    case notFound
    case missingDigest
    case httpStatus(Int)
    case tokenUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The registry returned an invalid response."
        case .unauthorized: return "The registry requires authentication."
        case .notFound: return "The image or tag was not found."
        case .missingDigest: return "The registry response did not include a content digest."
        case .httpStatus(let code): return "The registry returned HTTP \(code)."
        case .tokenUnavailable: return "Couldn't get a registry authorization token."
        }
    }
}

public struct RegistryManifestClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func remoteDigest(for imageRef: String) async throws -> String {
        let ref = RegistryImageReference.parse(imageRef)
        return try await remoteDigest(for: ref)
    }

    public func remoteDigest(for ref: RegistryImageReference) async throws -> String {
        let initial = try await manifestResponse(for: ref, bearerToken: nil)
        if initial.status == 401, let challenge = BearerChallenge(header: initial.authHeader) {
            let token = try await token(for: challenge, fallbackScope: ref.authScope)
            return try await digest(from: manifestResponse(for: ref, bearerToken: token))
        }
        return try digest(from: initial)
    }

    private func manifestResponse(for ref: RegistryImageReference, bearerToken: String?) async throws -> ManifestResponse {
        var request = URLRequest(url: ref.manifestURL)
        request.httpMethod = "HEAD"
        request.setValue(Self.acceptHeader, forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RegistryManifestError.invalidResponse }
        return ManifestResponse(
            status: http.statusCode,
            digest: http.value(forHTTPHeaderField: "Docker-Content-Digest"),
            authHeader: http.value(forHTTPHeaderField: "WWW-Authenticate")
        )
    }

    private func digest(from response: ManifestResponse) throws -> String {
        switch response.status {
        case 200..<300:
            guard let digest = response.digest, !digest.isEmpty else { throw RegistryManifestError.missingDigest }
            return digest
        case 401:
            throw RegistryManifestError.unauthorized
        case 404:
            throw RegistryManifestError.notFound
        default:
            throw RegistryManifestError.httpStatus(response.status)
        }
    }

    private func token(for challenge: BearerChallenge, fallbackScope: String) async throws -> String {
        var components = URLComponents(url: challenge.realm, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        if let service = challenge.service {
            items.append(URLQueryItem(name: "service", value: service))
        }
        items.append(URLQueryItem(name: "scope", value: challenge.scope ?? fallbackScope))
        components?.queryItems = items
        guard let url = components?.url else { throw RegistryManifestError.tokenUnavailable }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RegistryManifestError.tokenUnavailable
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let token = decoded.token ?? decoded.accessToken, !token.isEmpty else {
            throw RegistryManifestError.tokenUnavailable
        }
        return token
    }

    private struct ManifestResponse {
        let status: Int
        let digest: String?
        let authHeader: String?
    }

    private struct TokenResponse: Decodable {
        let token: String?
        let accessToken: String?

        enum CodingKeys: String, CodingKey {
            case token
            case accessToken = "access_token"
        }
    }

    private static let acceptHeader = [
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.docker.distribution.manifest.v2+json",
    ].joined(separator: ", ")
}

private struct BearerChallenge {
    let realm: URL
    let service: String?
    let scope: String?

    init?(header: String?) {
        guard let header, header.localizedCaseInsensitiveContains("Bearer") else { return nil }
        let value = header.dropFirst(header.prefix { !$0.isWhitespace }.count)
            .trimmingCharacters(in: .whitespaces)
        let params = Self.parameters(from: value)
        guard let realmString = params["realm"], let realm = URL(string: realmString) else { return nil }
        self.realm = realm
        service = params["service"]
        scope = params["scope"]
    }

    private static func parameters(from value: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var current = ""
        var inQuotes = false
        var readingKey = true

        func commit() {
            let trimmedKey = key.trimmingCharacters(in: .whitespaces)
            guard !trimmedKey.isEmpty else { return }
            result[trimmedKey] = current.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            key = ""
            current = ""
            readingKey = true
        }

        for char in value {
            switch char {
            case "\"":
                inQuotes.toggle()
                current.append(char)
            case "=" where readingKey:
                key = current
                current = ""
                readingKey = false
            case "," where !inQuotes:
                commit()
            default:
                current.append(char)
            }
        }
        commit()
        return result
    }
}
