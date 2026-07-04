import Foundation
import Testing

@Suite("Design system boundaries")
struct DesignSystemBoundaryTests {
    @Test func commandPreviewBarDoesNotHardcodeRuntimeExecutable() throws {
        let path = repositoryRoot
            .appendingPathComponent("Packages/ContainedUI/Sources/ContainedUI/Command/PreviewBar.swift")
        let content = try String(contentsOf: path, encoding: .utf8)

        #expect(!content.contains("[\"container\"] +"))
        #expect(!content.contains("public let command: [String]"))
        #expect(content.contains("public let commandText: String"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
