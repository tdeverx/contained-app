import Foundation
import Testing
@testable import Contained

@MainActor
struct UpdaterControllerTests {
    @Test func whatsNewIsNotMarkedSeenUntilClose() {
        let defaults = UserDefaults(suiteName: "ContainedUpdaterTests-\(UUID().uuidString)")!
        let updater = UpdaterController(defaults: defaults)

        #expect(defaults.string(forKey: "updates.lastSeenVersion") == nil)

        updater.presentCurrentReleaseNotes()
        updater.markWhatsNewSeen()

        #expect(!updater.showWhatsNew)
        #expect(defaults.string(forKey: "updates.lastSeenVersion") != nil)
    }

    @Test func manualReleaseNotesPresentationWorksAfterSeen() {
        let defaults = UserDefaults(suiteName: "ContainedUpdaterTests-\(UUID().uuidString)")!
        let updater = UpdaterController(defaults: defaults)

        updater.markWhatsNewSeen()
        updater.presentCurrentReleaseNotes()

        #expect(updater.showWhatsNew)
    }

    @Test func availableUpdateNotesTrackDetectedVersionAndClear() {
        let defaults = UserDefaults(suiteName: "ContainedUpdaterTests-\(UUID().uuidString)")!
        let updater = UpdaterController(defaults: defaults)

        updater.recordAvailableUpdate(itemDescription: "<h3>Added</h3>", displayVersion: "1.0.0-nightly.55+abc123")

        #expect(updater.availableUpdateDisplayVersion == "1.0.0-nightly.55+abc123")
        #expect(updater.availableReleaseNotesHTML == "<h3>Added</h3>")

        updater.clearAvailableUpdate()

        #expect(updater.availableUpdateDisplayVersion == nil)
        #expect(updater.availableReleaseNotesHTML == nil)
    }

    @Test func availableUpdateWithoutEmbeddedNotesStillShowsDetectedVersion() {
        let defaults = UserDefaults(suiteName: "ContainedUpdaterTests-\(UUID().uuidString)")!
        let updater = UpdaterController(defaults: defaults)

        updater.recordAvailableUpdate(itemDescription: nil, displayVersion: "1.0.0")

        #expect(updater.availableUpdateDisplayVersion == "1.0.0")
        #expect(updater.availableReleaseNotesHTML?.contains("No release notes are available for 1.0.0.") == true)
    }

    @Test func bundledChangelogResourceMatchesReleaseChangelog() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let releaseChangelog = root.appendingPathComponent("CHANGELOG.md")
        let bundledChangelog = root.appendingPathComponent("Sources/Contained/Resources/CHANGELOG.md")

        let releaseText = try String(contentsOf: releaseChangelog, encoding: .utf8)
        let bundledText = try String(contentsOf: bundledChangelog, encoding: .utf8)

        #expect(bundledText == releaseText)
    }

    @Test func bundledReleaseNotesAreReadable() {
        let updater = UpdaterController(defaults: UserDefaults(suiteName: "ContainedUpdaterTests-\(UUID().uuidString)")!)

        #expect(!updater.currentReleaseNotesHTML.contains("No release notes are bundled"))
        #expect(updater.currentReleaseNotesHTML.contains("First complete Contained release"))
    }

    @Test func prereleaseVersionsUseBaseChangelogSection() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let releaseChangelog = root.appendingPathComponent("CHANGELOG.md")
        let releaseText = try String(contentsOf: releaseChangelog, encoding: .utf8)

        let section = ChangelogSection.extract(version: "1.0.0-beta.1+abc123", from: releaseText)

        #expect(section?.contains("First complete Contained release") == true)
    }

    @Test func inAppReleaseNotesComposeBuildChangesBeforeFullVersionNotes() throws {
        let changelog = """
        # Changelog

        ## [Unreleased] - Current Build

        ### Fixed

        #### Polish

        - Build-level note.

        ## [1.0.0] - Version Notes

        ### Added

        - Version-level note.
        """

        let html = try #require(ChangelogSection.releaseNotesHTML(version: "1.0.0-nightly.999+abcdef",
                                                                  from: changelog))
        let changesHeading = try #require(html.range(of: "<h2>Changes Since Last Nightly</h2>"))
        let fullHeading = try #require(html.range(of: "<h2>Full Release Notes</h2>"))

        #expect(changesHeading.lowerBound < fullHeading.lowerBound)
        #expect(html.contains("<h4>Polish</h4>"))
        #expect(html.contains("Build-level note."))
        #expect(html.contains("Version-level note."))
    }

    @Test func appBundleChangelogURLUsesContentsResources() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedUpdaterTests-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Contained.app")
        let resources = app.appendingPathComponent("Contents/Resources/Contained_Contained.bundle")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try "# Changelog\n".write(to: resources.appendingPathComponent("CHANGELOG.md"),
                                  atomically: true,
                                  encoding: .utf8)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)

        let bundle = try #require(Bundle(url: app))
        let url = UpdaterController.changelogResourceURL(bundle: bundle)

        #expect(url == resources.appendingPathComponent("CHANGELOG.md"))
    }

    @Test func releaseNotesScriptComposesNightlyChangesAndFullNotes() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedReleaseNotesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let releaseNotes = work.appendingPathComponent("RELEASE_NOTES.md")
        try """
        # Release Notes

        ## [1.0.0] - Version Notes

        ### Added

        - Version-level release note.
        """.write(to: releaseNotes, atomically: true, encoding: .utf8)
        let changes = work.appendingPathComponent("CHANGES.md")
        try """
        # Changes

        ## [nightly] - Current Nightly

        ### Fixed

        #### Polish

        - Nightly-only build note.
        """.write(to: changes, atomically: true, encoding: .utf8)
        let archive = work.appendingPathComponent("Contained-1.0.0-nightly.999+abcdef.dmg")
        FileManager.default.createFile(atPath: archive.path, contents: Data())

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["./scripts/release-notes.sh", work.path]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "CHANGELOG": releaseNotes.path,
            "RELEASE_NOTES": releaseNotes.path,
            "CHANGES": changes.path,
            "CHANNEL": "nightly",
            "VERSION_VALUE": "1.0.0-nightly.999+abcdef",
        ], uniquingKeysWith: { _, new in new })

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let html = try String(contentsOf: work.appendingPathComponent("Contained-1.0.0-nightly.999+abcdef.html"),
                              encoding: .utf8)
        let changesHeading = try #require(html.range(of: "<h2>Changes Since Last Nightly</h2>"))
        let fullHeading = try #require(html.range(of: "<h2>Full Release Notes</h2>"))
        #expect(changesHeading.lowerBound < fullHeading.lowerBound)
        #expect(html.contains("<h4>Polish</h4>"))
        #expect(html.contains("Nightly-only build note."))
        #expect(html.contains("Version-level release note."))
        #expect(!html.contains("No release notes were found"))
    }

    @Test func betaReleaseNotesIncludeBetaChangesAndFullNotes() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedReleaseNotesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let releaseNotes = work.appendingPathComponent("RELEASE_NOTES.md")
        try """
        # Release Notes

        ## [1.0.0] - Version Notes

        ### Added

        - Version-level release note.
        """.write(to: releaseNotes, atomically: true, encoding: .utf8)
        let changes = work.appendingPathComponent("CHANGES.md")
        try """
        # Changes

        ## [beta] - Current Beta

        ### Fixed

        - Beta-only build note.

        ## [nightly] - Current Nightly

        ### Fixed

        - Nightly-only build note.
        """.write(to: changes, atomically: true, encoding: .utf8)
        let archive = work.appendingPathComponent("Contained-1.0.0-beta.999+abcdef.dmg")
        FileManager.default.createFile(atPath: archive.path, contents: Data())

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["./scripts/release-notes.sh", work.path]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "CHANGELOG": releaseNotes.path,
            "RELEASE_NOTES": releaseNotes.path,
            "CHANGES": changes.path,
            "CHANNEL": "beta",
            "VERSION_VALUE": "1.0.0-beta.999+abcdef",
        ], uniquingKeysWith: { _, new in new })

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let html = try String(contentsOf: work.appendingPathComponent("Contained-1.0.0-beta.999+abcdef.html"),
                              encoding: .utf8)
        #expect(html.contains("<h2>Changes Since Last Beta</h2>"))
        #expect(html.contains("<h2>Full Release Notes</h2>"))
        #expect(html.contains("Beta-only build note."))
        #expect(!html.contains("Nightly-only build note."))
        #expect(html.contains("Version-level release note."))
    }

    @Test func stableReleaseNotesOnlyIncludeFullVersionNotes() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedReleaseNotesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let releaseNotes = work.appendingPathComponent("RELEASE_NOTES.md")
        try """
        # Release Notes

        ## [1.0.0] - Version Notes

        ### Added

        - Version-level release note.
        """.write(to: releaseNotes, atomically: true, encoding: .utf8)
        let changes = work.appendingPathComponent("CHANGES.md")
        try """
        # Changes

        ## [Unreleased] - Current Build

        ### Fixed

        - Build-only note.
        """.write(to: changes, atomically: true, encoding: .utf8)
        let archive = work.appendingPathComponent("Contained-1.0.0.dmg")
        FileManager.default.createFile(atPath: archive.path, contents: Data())

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["./scripts/release-notes.sh", work.path]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "CHANGELOG": releaseNotes.path,
            "RELEASE_NOTES": releaseNotes.path,
            "CHANGES": changes.path,
            "CHANNEL": "stable",
            "VERSION_VALUE": "1.0.0",
        ], uniquingKeysWith: { _, new in new })

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let html = try String(contentsOf: work.appendingPathComponent("Contained-1.0.0.html"),
                              encoding: .utf8)
        #expect(!html.contains("Changes Since Last"))
        #expect(html.contains("<h2>Full Release Notes</h2>"))
        #expect(!html.contains("Build-only note."))
        #expect(html.contains("Version-level release note."))
    }

    @Test func betaReleaseNotesCanCompileChangeFragments() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedReleaseNotesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let releaseNotes = work.appendingPathComponent("RELEASE_NOTES.md")
        try """
        # Release Notes

        ## [1.0.0] - Version Notes

        ### Added

        - Version-level release note.
        """.write(to: releaseNotes, atomically: true, encoding: .utf8)
        let changesDir = work.appendingPathComponent("changes-beta")
        try FileManager.default.createDirectory(at: changesDir, withIntermediateDirectories: true)
        try """
        ### Fixed

        - First beta change fragment.
        """.write(to: changesDir.appendingPathComponent("001-first.md"), atomically: true, encoding: .utf8)
        try """
        ### Changed

        - Second beta change fragment.
        """.write(to: changesDir.appendingPathComponent("002-second.md"), atomically: true, encoding: .utf8)
        let archive = work.appendingPathComponent("Contained-1.0.0-beta.999+abcdef.dmg")
        FileManager.default.createFile(atPath: archive.path, contents: Data())

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["./scripts/release-notes.sh", work.path]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "CHANGELOG": releaseNotes.path,
            "RELEASE_NOTES": releaseNotes.path,
            "CHANGES": releaseNotes.path,
            "CHANGES_DIR": changesDir.path,
            "CHANNEL": "beta",
            "VERSION_VALUE": "1.0.0-beta.999+abcdef",
        ], uniquingKeysWith: { _, new in new })

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let html = try String(contentsOf: work.appendingPathComponent("Contained-1.0.0-beta.999+abcdef.html"),
                              encoding: .utf8)
        #expect(html.contains("<h2>Changes Since Last Beta</h2>"))
        #expect(html.contains("First beta change fragment."))
        #expect(html.contains("Second beta change fragment."))
        #expect(html.contains("Version-level release note."))
    }

    @Test func promotedAppcastItemsMergeIntoNightlyIdempotently() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedAppcastMergeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let promoted = work.appendingPathComponent("promoted.xml")
        let nightly = work.appendingPathComponent("nightly.xml")

        try """
        <?xml version="1.0" standalone="yes"?>
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
            <channel>
                <title>Contained</title>
                <item>
                    <title>1.0.0-beta.120+abc123</title>
                    <sparkle:version>120</sparkle:version>
                    <sparkle:shortVersionString>1.0.0-beta.120+abc123</sparkle:shortVersionString>
                </item>
            </channel>
        </rss>
        """.write(to: promoted, atomically: true, encoding: .utf8)

        try """
        <?xml version="1.0" standalone="yes"?>
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
            <channel>
                <title>Contained</title>
                <item>
                    <title>old beta item</title>
                    <sparkle:version>120</sparkle:version>
                    <sparkle:shortVersionString>1.0.0-beta.120+old</sparkle:shortVersionString>
                </item>
                <item>
                    <title>1.0.0-nightly.119+def456</title>
                    <sparkle:version>119</sparkle:version>
                    <sparkle:shortVersionString>1.0.0-nightly.119+def456</sparkle:shortVersionString>
                </item>
            </channel>
        </rss>
        """.write(to: nightly, atomically: true, encoding: .utf8)

        for _ in 0..<2 {
            let process = Process()
            process.currentDirectoryURL = root
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["./scripts/promote-appcast-to-nightly.sh", promoted.path, nightly.path]
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
        }

        let merged = try String(contentsOf: nightly, encoding: .utf8)
        let promotedBuildOccurrences = merged.components(separatedBy: "<sparkle:version>120</sparkle:version>").count - 1
        #expect(promotedBuildOccurrences == 1)
        #expect(merged.contains("1.0.0-beta.120+abc123"))
        #expect(!merged.contains("old beta item"))
        #expect(merged.contains("1.0.0-nightly.119+def456"))
    }
}
