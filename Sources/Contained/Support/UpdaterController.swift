import SwiftUI
import Sparkle

/// Thin wrapper over Sparkle's standard updater. Inert until a signed build sets `SUFeedURL` +
/// `SUPublicEDKey` in Info.plist and points them at a hosted appcast.
///
/// Channels: each channel (stable/beta/nightly) reads a branch-hosted appcast feed at the matching
/// git branch's repo root (see `UpdateChannel.feedURL`). Stable and beta are branch-local feeds;
/// nightly is a superset feed that also carries promoted beta/stable items. The `ChannelDelegate`
/// overrides Sparkle's `SUFeedURL` per the selected channel via `feedURLString(for:)`.
@MainActor
@Observable
final class UpdaterController {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private let channelDelegate = ChannelDelegate()
    @ObservationIgnored private let defaults: UserDefaults

    private static let lastSeenVersionKey = "updates.lastSeenVersion"

    var availableReleaseNotesHTML: String?
    var availableUpdateDisplayVersion: String?
    var showWhatsNew = false

    init(channel: UpdateChannel = .nightly, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        channelDelegate.channel = channel
        channelDelegate.onUpdateFound = { [weak self] item in
            self?.recordAvailableUpdate(itemDescription: item.itemDescription,
                                        displayVersion: item.displayVersionString)
        }
        channelDelegate.onNoUpdateFound = { [weak self] in
            self?.clearAvailableUpdate()
        }
        // Seed the current channel as available so the picker shows a valid selection immediately;
        // the probe fills in (or removes) the rest.
        availableChannels = [channel]
        // Sparkle requires a code-signed host with a valid feed; starting it in an unsigned/dev
        // build aborts. Only start it in release builds — the dev bundle isn't signed.
        #if !DEBUG
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: channelDelegate, userDriverDelegate: nil)
        #endif
        showWhatsNewIfNeeded()
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }
    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }

    func presentCurrentReleaseNotes() {
        showWhatsNew = true
    }

    func recordAvailableUpdate(itemDescription: String?, displayVersion: String) {
        let trimmed = itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        availableReleaseNotesHTML = trimmed?.isEmpty == false
            ? trimmed
            : "<p>No release notes are available for \(displayVersion).</p>"
        availableUpdateDisplayVersion = displayVersion
    }

    func clearAvailableUpdate() {
        availableReleaseNotesHTML = nil
        availableUpdateDisplayVersion = nil
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? true }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Switch the channel; a background information check re-queries the new feed immediately.
    var channel: UpdateChannel = .nightly {
        didSet {
            channelDelegate.channel = channel
            controller?.updater.checkForUpdateInformation()
        }
    }

    /// Channels whose feed currently resolves (HTTP 200). The Updates picker dims the rest, since a
    /// channel without a published `appcast.xml` (e.g. beta/stable before their first release) has
    /// nothing to update to. Seeded with the current channel; `refreshChannelAvailability()` probes
    /// the others. Empty-feed channels light up automatically once their branch publishes.
    private(set) var availableChannels: Set<UpdateChannel> = []
    @ObservationIgnored private var availabilityTask: Task<Void, Never>?

    /// Probe every channel's feed URL (a cheap HEAD) and update `availableChannels`. Safe to call
    /// repeatedly; cancels any in-flight probe. Runs in DEBUG too — it's plain networking, decoupled
    /// from Sparkle (which is inert in dev builds).
    func refreshChannelAvailability() {
        availabilityTask?.cancel()
        availabilityTask = Task { [weak self] in
            var found: Set<UpdateChannel> = []
            for channel in UpdateChannel.allCases where await Self.feedExists(channel.feedURL) {
                found.insert(channel)
            }
            guard !Task.isCancelled, let self else { return }
            // Never strand the current selection: keep it shown even if its feed momentarily fails.
            found.insert(self.channel)
            self.availableChannels = found
        }
    }

    private static func feedExists(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 10
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    var currentReleaseNotesHTML: String {
        Self.releaseNotesHTML(for: Self.runningDisplayVersion()) ?? "<p>No release notes are bundled for this build.</p>"
    }

    func markWhatsNewSeen() {
        defaults.set(Self.runningDisplayVersion(), forKey: Self.lastSeenVersionKey)
        showWhatsNew = false
    }

    private func showWhatsNewIfNeeded() {
        let version = Self.runningDisplayVersion()
        guard defaults.string(forKey: Self.lastSeenVersionKey) != version else { return }
        showWhatsNew = Self.releaseNotesHTML(for: version) != nil
    }

    private static func runningDisplayVersion() -> String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String)
            ?? (info?["CFBundleVersion"] as? String)
            ?? "1.0"
    }

    private static func releaseNotesHTML(for version: String) -> String? {
        guard let url = changelogResourceURL(),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return ChangelogSection.releaseNotesHTML(version: version, from: text)
    }

    static func changelogResourceURL(bundle: Bundle = .main) -> URL? {
        if bundle.bundleURL.pathExtension == "app" {
            return bundle.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Resources")
                .appendingPathComponent("Contained_Contained.bundle")
                .appendingPathComponent("CHANGELOG.md")
        }
        return Bundle.module.url(forResource: "CHANGELOG", withExtension: "md")
    }

    /// Sparkle's delegate must be an `NSObject`. It points the updater at the selected channel's feed
    /// (overriding `SUFeedURL`) and reports the allowed channel set (empty — feed selection *is* the
    /// channel with per-branch feeds).
    private final class ChannelDelegate: NSObject, SPUUpdaterDelegate {
        var channel: UpdateChannel = .nightly
        var onUpdateFound: ((SUAppcastItem) -> Void)?
        var onNoUpdateFound: (() -> Void)?
        func feedURLString(for updater: SPUUpdater) -> String? { channel.feedURL }
        func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel.allowedChannels }
        func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
            onUpdateFound?(item)
        }
        func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
            onNoUpdateFound?()
        }
        func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
            onNoUpdateFound?()
        }
    }
}

enum ChangelogSection {
    enum Channel {
        case stable, beta, nightly

        init(version: String) {
            if version.contains("-nightly.") {
                self = .nightly
            } else if version.contains("-beta.") {
                self = .beta
            } else {
                self = .stable
            }
        }

        var changesTitle: String? {
            switch self {
            case .stable: return nil
            case .beta: return "Changes Since Last Beta"
            case .nightly: return "Changes Since Last Nightly"
            }
        }
    }

    static func releaseNotesHTML(version: String, from changelog: String) -> String? {
        releaseNotesMarkdown(version: version, from: changelog).map(html(from:))
    }

    static func releaseNotesMarkdown(version: String, from changelog: String) -> String? {
        let channel = Channel(version: version)
        let base = baseVersion(version)
        let fullNotes = extractFirst(candidates: [base, version], from: changelog)
            ?? extractFirst(candidates: ["Unreleased"], from: changelog)
        var sections: [String] = []

        if let changesTitle = channel.changesTitle,
           let changes = extractChanges(version: version, channel: channel, from: changelog),
           changes != fullNotes {
            sections.append("## \(changesTitle)\n\n\(changes)")
        }

        if let fullNotes {
            sections.append("## Full Release Notes\n\n\(fullNotes)")
        }

        guard !sections.isEmpty else { return nil }
        return sections.joined(separator: "\n\n")
    }

    private static func extractChanges(version: String, channel: Channel, from changelog: String) -> String? {
        let channelVersion: String
        switch channel {
        case .stable:
            return nil
        case .beta:
            channelVersion = "beta"
        case .nightly:
            channelVersion = "nightly"
        }

        return extractFirst(candidates: [version, channelVersion, "Unreleased"], from: changelog)
    }

    private static func baseVersion(_ version: String) -> String {
        version.split(separator: "+", maxSplits: 1).first
            .flatMap { $0.split(separator: "-", maxSplits: 1).first }
            .map(String.init) ?? version
    }

    static func extract(version: String, from changelog: String) -> String? {
        let base = baseVersion(version)
        return extractFirst(candidates: [version, base, "Unreleased"], from: changelog)
    }

    private static func extractFirst(candidates: [String], from changelog: String) -> String? {
        let lines = changelog.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let start = candidates.compactMap { candidate in
            lines.firstIndex(where: { line in
                line.hasPrefix("## ") && (line.contains(candidate) || line.contains("[\(candidate)]"))
            })
        }.first
        guard let start else { return nil }
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex
        let section = lines[(start + 1)..<end]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return section.isEmpty ? nil : section
    }

    static func html(from markdown: String) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let lines = escaped.split(separator: "\n", omittingEmptySubsequences: false)
        var html = ""
        var inList = false
        for line in lines {
            if line.hasPrefix("### ") {
                if inList { html += "</ul>"; inList = false }
                html += "<h3>\(line.dropFirst(4))</h3>"
            } else if line.hasPrefix("## ") {
                if inList { html += "</ul>"; inList = false }
                html += "<h2>\(line.dropFirst(3))</h2>"
            } else if line.hasPrefix("#### ") {
                if inList { html += "</ul>"; inList = false }
                html += "<h4>\(line.dropFirst(5))</h4>"
            } else if line.hasPrefix("- ") {
                if !inList { html += "<ul>"; inList = true }
                html += "<li>\(line.dropFirst(2))</li>"
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                if !inList { html += "<ul>"; inList = true }
                let item = line.trimmingCharacters(in: .whitespaces).dropFirst(2)
                html += "<li>\(item)</li>"
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if inList { html += "</ul>"; inList = false }
            } else {
                if inList { html += "</ul>"; inList = false }
                html += "<p>\(line)</p>"
            }
        }
        if inList { html += "</ul>" }
        return html
    }
}
