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
        #expect(updater.currentReleaseNotesHTML.contains("Sparkle release notes"))
    }

    @Test func prereleaseVersionsUseBaseChangelogSection() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let releaseChangelog = root.appendingPathComponent("CHANGELOG.md")
        let releaseText = try String(contentsOf: releaseChangelog, encoding: .utf8)

        let section = ChangelogSection.extract(version: "1.0.0-beta.1+abc123", from: releaseText)

        #expect(section?.contains("Sparkle release notes") == true)
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

    @Test func releaseNotesScriptUsesBaseVersionForPrereleases() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ContainedReleaseNotesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let archive = work.appendingPathComponent("Contained-1.0.0-nightly.999+abcdef.dmg")
        FileManager.default.createFile(atPath: archive.path, contents: Data())

        let process = Process()
        process.currentDirectoryURL = root
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-lc", "VERSION_VALUE='1.0.0-nightly.999+abcdef' ./scripts/release-notes.sh '\(work.path)'"]

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let html = try String(contentsOf: work.appendingPathComponent("Contained-1.0.0-nightly.999+abcdef.html"),
                              encoding: .utf8)
        #expect(html.contains("Sparkle release notes"))
        #expect(!html.contains("No release notes were found"))
    }
}
