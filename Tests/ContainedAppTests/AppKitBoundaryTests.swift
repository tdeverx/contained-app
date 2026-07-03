import Foundation
import Testing
import ContainedCore
@testable import ContainedApp

@Suite("AppKit containment")
struct AppKitBoundaryTests {
    private let allowedAppKitImportPaths: Set<String> = [
        "Sources/ContainedApp/Services/Platform/Platform.swift",
        "Sources/ContainedApp/Services/Platform/TerminalSurface.swift",
        "Packages/ContainedUI/Sources/ContainedUI/Surface/VisualEffectBackground.swift",
    ]

    private let appKitOnlySymbols = [
        "NSOpenPanel",
        "NSSavePanel",
        "NSWorkspace",
        "NSPasteboard",
        "NSHapticFeedbackManager",
        "NSImage(systemSymbolName",
        "WKWebView",
    ]

    @Test func appKitImportsStayInsideApprovedBridgeFiles() throws {
        let allowedImportPaths = allowedAppKitImportPaths.union(["Tests/ContainedAppTests/AppKitBoundaryTests.swift"])
        let violations = try swiftFiles()
            .filter { file in
                let content = try String(contentsOf: file, encoding: .utf8)
                return content.contains("import AppKit") && !allowedImportPaths.contains(relativePath(file))
            }
            .map(relativePath)
            .sorted()

        #expect(violations == [])
    }

    @Test func removedAppKitConvenienceSymbolsDoNotReturnOutsideBridgeFiles() throws {
        let allowedSymbolPaths = allowedAppKitImportPaths.union(["Tests/ContainedAppTests/AppKitBoundaryTests.swift"])
        let violations = try swiftFiles().flatMap { file -> [String] in
            let path = relativePath(file)
            guard !allowedSymbolPaths.contains(path) else { return [] }
            let content = try String(contentsOf: file, encoding: .utf8)
            return appKitOnlySymbols
                .filter { content.contains($0) }
                .map { "\(path): \($0)" }
        }.sorted()

        #expect(violations == [])
    }

    private func swiftFiles() throws -> [URL] {
        let root = repositoryRoot
        let searchRoots = ["Sources", "Packages", "Tests"].map { root.appendingPathComponent($0) }
        var files: [URL] = []
        for root in searchRoots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for item in enumerator {
                guard let url = item as? URL else { continue }
                if url.path.contains("/.build/") { continue }
                guard url.pathExtension == "swift" else { continue }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                if values.isRegularFile == true {
                    files.append(url)
                }
            }
        }
        return files
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func relativePath(_ url: URL) -> String {
        let rootPath = repositoryRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return path }
        return String(path.dropFirst(rootPath.count + 1))
    }
}

@Suite("Personalization symbols")
struct PersonalizationSymbolTests {
    @Test func customContainerSymbolDoesNotUseAppKitValidation() {
        var personalization = Personalization()
        personalization.icon = "not.a.real.symbol"

        #expect(personalization.symbol == "not.a.real.symbol")
    }

    @Test func emptyOrDisabledContainerSymbolUsesDefault() {
        var personalization = Personalization()
        #expect(personalization.symbol == Personalization.defaultSymbol)

        personalization.icon = "shippingbox"
        personalization.iconEnabled = false
        #expect(personalization.symbol == Personalization.defaultSymbol)
    }

    @Test func customWidgetSymbolDoesNotUseAppKitValidation() {
        var widget = WidgetConfiguration(metric: .cpu)
        widget.icon = "not.a.real.symbol"

        #expect(widget.resolvedSystemImage == "not.a.real.symbol")
    }

    @Test func emptyWidgetSymbolUsesMetricSymbol() {
        let widget = WidgetConfiguration(metric: .memory)

        #expect(widget.resolvedSystemImage == Core.Metrics.GraphMetric.memory.systemImage)
    }
}
