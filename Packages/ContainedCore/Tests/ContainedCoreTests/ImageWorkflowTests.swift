import Foundation
import Testing
@testable import ContainedCore

@Suite("Image workflow helpers", .serialized)
struct ImageWorkflowTests {
    @Test func registryReferenceNormalization() {
        let official = RegistryImageReference.parse("nginx")
        #expect(official.registry == "registry-1.docker.io")
        #expect(official.repository == "library/nginx")
        #expect(official.reference == "latest")
        #expect(official.normalizedKey == "docker.io/library/nginx:latest")

        let namespaced = RegistryImageReference.parse("docker.io/tdeverx/app:nightly")
        #expect(namespaced.registry == "registry-1.docker.io")
        #expect(namespaced.repository == "tdeverx/app")
        #expect(namespaced.reference == "nightly")
        #expect(namespaced.normalizedKey == "docker.io/tdeverx/app:nightly")

        let custom = RegistryImageReference.parse("ghcr.io/acme/app@sha256:abc")
        #expect(custom.registry == "ghcr.io")
        #expect(custom.repository == "acme/app")
        #expect(custom.reference == "sha256:abc")
        #expect(custom.isDigestReference)
        #expect(custom.normalizedKey == "ghcr.io/acme/app@sha256:abc")
    }

    @Test func imageUpdateStatusTransitions() {
        #expect(ImageUpdateStatus.checking(localDigest: "sha256:a").state == .checking)
        #expect(ImageUpdateStatus.resolved(localDigest: "sha256:a", remoteDigest: "sha256:a").state == .current)
        #expect(ImageUpdateStatus.resolved(localDigest: "sha256:a", remoteDigest: "sha256:b").state == .updateAvailable)
        let failed = ImageUpdateStatus.failed(localDigest: "sha256:a", message: "boom")
        #expect(failed.state == .error)
        #expect(failed.message == "boom")
    }

    @Test func localTagGroupingUsesDigest() throws {
        let json = """
        [
          {
            "configuration": {
              "name": "docker.io/library/alpine:latest",
              "descriptor": {"digest": "sha256:same", "mediaType": "application/vnd.oci.image.index.v1+json", "size": 12}
            },
            "id": "same",
            "variants": []
          },
          {
            "configuration": {
              "name": "localhost/alpine:test",
              "descriptor": {"digest": "sha256:same", "mediaType": "application/vnd.oci.image.index.v1+json", "size": 12}
            },
            "id": "same",
            "variants": []
          }
        ]
        """
        let images = try JSONDecoder().decode([ImageResource].self, from: Data(json.utf8))
        let groups = LocalImageTagGroup.groups(for: images)
        #expect(groups.count == 1)
        #expect(groups.first?.references == ["docker.io/library/alpine:latest", "localhost/alpine:test"])
    }

    @Test func hubSearchFetchesThroughSharedHelper() async throws {
        let session = Self.session { request in
            #expect(request.url?.path == "/v2/search/repositories")
            #expect(request.url?.query?.contains("query=nginx") == true)
            #expect(request.url?.query?.contains("page_size=25") == true)
            return Self.response(url: request.url!, status: 200, body: """
            {"results":[{"repo_name":"library/nginx","short_description":"web server","star_count":18000,"is_official":true,"is_automated":false}]}
            """)
        }
        let results = try await HubSearch.results(query: "nginx", session: session)
        #expect(results.map(\.pullReference) == ["nginx"])
    }

    @Test func registryManifestReadsDigest() async throws {
        let session = Self.session { request in
            #expect(request.httpMethod == "HEAD")
            #expect(request.url?.path == "/v2/library/nginx/manifests/latest")
            return Self.response(url: request.url!, status: 200, headers: [
                "Docker-Content-Digest": "sha256:remote",
            ])
        }
        let digest = try await RegistryManifestClient(session: session).remoteDigest(for: "nginx")
        #expect(digest == "sha256:remote")
    }

    @Test func registryManifestHandlesBearerChallenge() async throws {
        final class State: @unchecked Sendable { var manifestHits = 0 }
        let state = State()
        let session = Self.session { request in
            if request.url?.host == "auth.example.test" {
                #expect(request.url?.query?.contains("service=registry.example.test") == true)
                #expect(request.url?.query?.contains("scope=repository:team/app:pull") == true)
                return Self.response(url: request.url!, status: 200, body: #"{"token":"abc"}"#)
            }
            state.manifestHits += 1
            if state.manifestHits == 1 {
                return Self.response(url: request.url!, status: 401, headers: [
                    "WWW-Authenticate": #"Bearer realm="https://auth.example.test/token",service="registry.example.test",scope="repository:team/app:pull""#,
                ])
            }
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
            return Self.response(url: request.url!, status: 200, headers: [
                "Docker-Content-Digest": "sha256:after-auth",
            ])
        }
        let digest = try await RegistryManifestClient(session: session).remoteDigest(for: "registry.example.test/team/app:1")
        #expect(digest == "sha256:after-auth")
        #expect(state.manifestHits == 2)
    }

    @Test func registryManifestMapsFailures() async {
        let missingDigest = Self.session { request in
            Self.response(url: request.url!, status: 200)
        }
        await #expect(throws: RegistryManifestError.missingDigest) {
            _ = try await RegistryManifestClient(session: missingDigest).remoteDigest(for: "nginx")
        }

        let notFound = Self.session { request in
            Self.response(url: request.url!, status: 404)
        }
        await #expect(throws: RegistryManifestError.notFound) {
            _ = try await RegistryManifestClient(session: notFound).remoteDigest(for: "nginx")
        }

        let status = RegistryManifestError.httpStatus(500)
        #expect(status.packageName == "ContainedCore")
        #expect(status.packageErrorCode == "registryHTTPStatus")
        #expect(status.packageErrorContext["status"] == "500")
    }

    private static func session(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
        RegistryMockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RegistryMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func response(url: URL, status: Int, headers: [String: String] = [:],
                                 body: String = "") -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
        return (response, Data(body.utf8))
    }
}

private final class RegistryMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
