import Foundation
import Testing

@Suite("Runtime boundary conventions")
struct RuntimeBoundaryConventionTests {
    @Test func concreteRuntimeSymbolsStayInsideRuntimeFolders() throws {
        let packageRoot = try packageRootURL()
        let sourceRoot = packageRoot.appending(path: "Sources/ContainedCore")
        let forbiddenSymbols = [
            "AppleContainerClient",
            "DockerClient",
            "ContainerCommands",
            "DockerCommands",
            "AppleContainerCLILocator",
            "DockerCLILocator",
            "AppleContainerCreateTranslator",
            "DockerCreateTranslator",
            "ContainerStatsTableParser",
            "DockerJSON",
        ]

        let violations = try swiftFiles(under: sourceRoot).flatMap { url -> [String] in
            let path = url.path(percentEncoded: false)
            guard !path.contains("/Runtimes/") else { return [] }
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return forbiddenSymbols.compactMap { symbol in
                contents.contains(symbol) ? "\(path.replacingOccurrences(of: packageRoot.path(percentEncoded: false) + "/", with: "")) uses \(symbol)" : nil
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.joined(separator: "\n")))
    }

    @Test func removedWideRuntimeProtocolNameDoesNotReturn() throws {
        let packageRoot = try packageRootURL()
        let sourceAndTests = [
            packageRoot.appending(path: "Sources"),
            packageRoot.appending(path: "Tests"),
        ]
        let violations = try sourceAndTests.flatMap { root in
            try swiftFiles(under: root).compactMap { url -> String? in
                let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                guard contents.contains("ContainerRuntime" + "Client") else { return nil }
                return url.path(percentEncoded: false)
                    .replacingOccurrences(of: packageRoot.path(percentEncoded: false) + "/", with: "")
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.joined(separator: "\n")))
    }

    private func packageRootURL() throws -> URL {
        var url = URL(filePath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        return url
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return try enumerator.compactMap { item -> URL? in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}
