import Foundation

public extension Core.Registry {
enum ManifestError: Core.Error.PackageError, Equatable {
    case invalidResponse
    case unauthorized
    case notFound
    case missingDigest
    case httpStatus(Int)
    case tokenUnavailable

    public var packageName: String { "ContainedCore" }

    public var packageErrorCode: String {
        switch self {
        case .invalidResponse: return "registryInvalidResponse"
        case .unauthorized: return "registryUnauthorized"
        case .notFound: return "registryNotFound"
        case .missingDigest: return "registryMissingDigest"
        case .httpStatus: return "registryHTTPStatus"
        case .tokenUnavailable: return "registryTokenUnavailable"
        }
    }

    public var packageErrorContext: [String: String] {
        switch self {
        case .httpStatus(let code): return ["status": String(code)]
        case .invalidResponse, .unauthorized, .notFound, .missingDigest, .tokenUnavailable: return [:]
        }
    }
}

struct ManifestClient: Sendable {
    private let session: URLSession
    private let credentials: (@Sendable (String) throws -> RegistryCredentials?)?

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
        credentials = nil
    }

    internal init(session: URLSession = URLSession(configuration: .ephemeral),
         credentials: @escaping @Sendable (String) throws -> RegistryCredentials?) {
        self.session = session
        self.credentials = credentials
    }

    public func remoteDigest(for imageRef: String) async throws -> String {
        let ref = Core.Registry.ImageReference.parse(imageRef)
        return try await remoteDigest(for: ref)
    }

    public func remoteDigest(for ref: Core.Registry.ImageReference) async throws -> String {
        try await remoteManifest(for: ref).digest
    }

    func remoteManifest(for ref: Core.Registry.ImageReference) async throws -> ManifestResult {
        let initial = try await manifestResponse(for: ref, bearerToken: nil)
        if initial.status == 401, let challenge = BearerChallenge(header: initial.authHeader) {
            do {
                let token = try await token(for: challenge, fallbackScope: ref.authScope)
                let value = try await digest(from: manifestResponse(for: ref, bearerToken: token))
                return ManifestResult(digest: value, authenticated: false)
            } catch let error as ManifestError where error == .unauthorized || error == .tokenUnavailable {
                // Never send a saved password to a registry-supplied arbitrary auth server.
                guard Self.canSendCredentials(registry: ref.manifestURL, realm: challenge.realm),
                      let credential = try credentials?(ref.registry) else { throw error }
                let token = try await token(for: challenge, fallbackScope: ref.authScope, credential: credential)
                let value = try await digest(from: manifestResponse(for: ref, bearerToken: token))
                return ManifestResult(digest: value, authenticated: true)
            }
        }
        if initial.status == 401, initial.authHeader?.lowercased().hasPrefix("basic ") == true,
           let credential = try credentials?(ref.registry) {
            let value = try await digest(from: manifestResponse(for: ref, bearerToken: nil, credential: credential))
            return ManifestResult(digest: value, authenticated: true)
        }
        return ManifestResult(digest: try digest(from: initial), authenticated: false)
    }

    static func canSendCredentials(registry: URL, realm: URL) -> Bool {
        guard registry.scheme == "https", realm.scheme == "https",
              let registryHost = registry.host?.lowercased(), let realmHost = realm.host?.lowercased(),
              realm.user == nil, realm.password == nil else { return false }
        let registryPort = registry.port ?? 443
        let realmPort = realm.port ?? 443
        if registryHost == realmHost, registryPort == realmPort { return true }
        return registryHost == "registry-1.docker.io" && realmHost == "auth.docker.io" &&
            registryPort == 443 && realmPort == 443
    }

    private func manifestResponse(for ref: Core.Registry.ImageReference, bearerToken: String?,
                                  credential: RegistryCredentials? = nil) async throws -> ManifestResponse {
        var request = URLRequest(url: ref.manifestURL)
        request.timeoutInterval = 20
        request.httpMethod = "HEAD"
        request.setValue(Self.acceptHeader, forHTTPHeaderField: "Accept")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        } else if let credential {
            request.setValue(credential.authorization, forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await session.data(for: request, delegate: RegistryRedirectBlocker.shared)
        guard let http = response as? HTTPURLResponse else { throw Core.Registry.ManifestError.invalidResponse }
        return ManifestResponse(
            status: http.statusCode,
            digest: http.value(forHTTPHeaderField: "Docker-Content-Digest"),
            authHeader: http.value(forHTTPHeaderField: "WWW-Authenticate")
        )
    }

    private func digest(from response: ManifestResponse) throws -> String {
        switch response.status {
        case 200..<300:
            guard let digest = response.digest, !digest.isEmpty else { throw Core.Registry.ManifestError.missingDigest }
            return digest
        case 401, 403:
            throw Core.Registry.ManifestError.unauthorized
        case 404:
            throw Core.Registry.ManifestError.notFound
        default:
            throw Core.Registry.ManifestError.httpStatus(response.status)
        }
    }

    private func token(for challenge: BearerChallenge, fallbackScope: String,
                       credential: RegistryCredentials? = nil) async throws -> String {
        guard challenge.realm.scheme == "https", challenge.realm.user == nil,
              challenge.realm.password == nil else { throw ManifestError.tokenUnavailable }
        var components = URLComponents(url: challenge.realm, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        if let service = challenge.service {
            items.append(URLQueryItem(name: "service", value: service))
        }
        items.append(URLQueryItem(name: "scope", value: challenge.scope ?? fallbackScope))
        components?.queryItems = items
        guard let url = components?.url else { throw Core.Registry.ManifestError.tokenUnavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        if let credential { request.setValue(credential.authorization, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request, delegate: RegistryRedirectBlocker.shared)
        guard let http = response as? HTTPURLResponse else { throw ManifestError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw ManifestError.unauthorized }
        if http.statusCode == 429 { throw ManifestError.httpStatus(429) }
        guard (200..<300).contains(http.statusCode) else {
            throw Core.Registry.ManifestError.tokenUnavailable
        }
        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw ManifestError.tokenUnavailable
        }
        guard let token = decoded.token ?? decoded.accessToken, !token.isEmpty else {
            throw Core.Registry.ManifestError.tokenUnavailable
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

struct ManifestResult: Sendable, Equatable {
    public let digest: String
    public let authenticated: Bool
    public init(digest: String, authenticated: Bool) {
        self.digest = digest
        self.authenticated = authenticated
    }
}

private struct BearerChallenge {
    let realm: URL
    let service: String?
    let scope: String?

    init?(header: String?) {
        guard let header, header.lowercased().hasPrefix("bearer ") else { return nil }
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

/// Ephemeral, non-serializable credential material, confined to the runtime adapter.
internal struct RegistryCredentials: Sendable {
    let username: String
    let password: String
    var authorization: String { "Basic " + Data("\(username):\(password)".utf8).base64EncodedString() }
}

private final class RegistryRedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = RegistryRedirectBlocker()
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

}
