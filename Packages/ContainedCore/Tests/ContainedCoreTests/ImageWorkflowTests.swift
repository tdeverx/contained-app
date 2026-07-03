import Foundation
import Testing
@testable import ContainedCore

@Suite("Image workflow helpers", .serialized)
struct ImageWorkflowTests {
    @Test func registryReferenceNormalization() {
        let official = Core.Registry.ImageReference.parse("nginx")
        #expect(official.registry == "registry-1.docker.io")
        #expect(official.repository == "library/nginx")
        #expect(official.reference == "latest")
        #expect(official.normalizedKey == "docker.io/library/nginx:latest")

        let namespaced = Core.Registry.ImageReference.parse("docker.io/tdeverx/app:nightly")
        #expect(namespaced.registry == "registry-1.docker.io")
        #expect(namespaced.repository == "tdeverx/app")
        #expect(namespaced.reference == "nightly")
        #expect(namespaced.normalizedKey == "docker.io/tdeverx/app:nightly")

        let custom = Core.Registry.ImageReference.parse("ghcr.io/acme/app@sha256:abc")
        #expect(custom.registry == "ghcr.io")
        #expect(custom.repository == "acme/app")
        #expect(custom.reference == "sha256:abc")
        #expect(custom.isDigestReference)
        #expect(custom.normalizedKey == "ghcr.io/acme/app@sha256:abc")
    }

    @Test func imageUpdateStatusTransitions() {
        #expect(Core.Image.UpdateStatus.checking(localDigest: "sha256:a").state == .checking)
        #expect(Core.Image.UpdateStatus.resolved(localDigest: "sha256:a", remoteDigest: "sha256:a").state == .current)
        #expect(Core.Image.UpdateStatus.resolved(localDigest: "sha256:a", remoteDigest: "sha256:b").state == .updateAvailable)
        let failed = Core.Image.UpdateStatus.failed(localDigest: "sha256:a", message: "boom")
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
        let images = try JSONDecoder().decode([Core.Image.Resource].self, from: Data(json.utf8))
        let groups = Core.Image.LocalTagGroup.groups(for: images)
        #expect(groups.count == 1)
        #expect(groups.first?.references == ["docker.io/library/alpine:latest", "localhost/alpine:test"])
    }

    @Test func localTagGroupingKeepsRuntimeSpecificAvailability() {
        let apple = Self.image(reference: "docker.io/library/nginx:latest",
                               digest: "sha256:same",
                               runtimeKind: .appleContainer)
        let docker = Self.image(reference: "nginx:latest",
                                digest: "sha256:same",
                                runtimeKind: .docker)

        let group = Core.Image.LocalTagGroup.groups(for: [apple, docker]).first

        #expect(group?.images.count == 2)
        #expect(group?.references == ["docker.io/library/nginx:latest", "nginx:latest"])
        #expect(group?.tags.count == 2)
        let runtimeKinds = Set(group?.tags.map(\.runtimeKind) ?? [])
        let tagIDs = group?.tags.map(\.id) ?? []
        #expect(runtimeKinds == Set([Core.Runtime.Kind.appleContainer, .docker]))
        #expect(tagIDs.allSatisfy { $0.contains("::") })
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
        let results = try await Core.Registry.HubSearch.results(query: "nginx", session: session)
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
        let digest = try await Core.Registry.ManifestClient(session: session).remoteDigest(for: "nginx")
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
        let digest = try await Core.Registry.ManifestClient(session: session).remoteDigest(for: "registry.example.test/team/app:1")
        #expect(digest == "sha256:after-auth")
        #expect(state.manifestHits == 2)
    }

    @Test func registryManifestMapsFailures() async {
        let missingDigest = Self.session { request in
            Self.response(url: request.url!, status: 200)
        }
        await #expect(throws: Core.Registry.ManifestError.missingDigest) {
            _ = try await Core.Registry.ManifestClient(session: missingDigest).remoteDigest(for: "nginx")
        }

        let notFound = Self.session { request in
            Self.response(url: request.url!, status: 404)
        }
        await #expect(throws: Core.Registry.ManifestError.notFound) {
            _ = try await Core.Registry.ManifestClient(session: notFound).remoteDigest(for: "nginx")
        }

        let status = Core.Registry.ManifestError.httpStatus(500)
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

    private static func image(reference: String,
                              digest: String,
                              runtimeKind: Core.Runtime.Kind) -> Core.Image.Resource {
        Core.Image.Resource(configuration: Core.Image.Configuration(
            name: reference,
            descriptor: Core.Container.Descriptor(digest: digest,
                                                  mediaType: "application/vnd.oci.image.index.v1+json",
                                                  size: 12),
            creationDate: nil
        ),
        id: digest,
        variants: [],
        runtimeKind: runtimeKind)
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
