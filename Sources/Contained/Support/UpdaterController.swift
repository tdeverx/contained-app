import SwiftUI
import Sparkle

/// Thin wrapper over Sparkle's standard updater. Inert until a signed build sets `SUFeedURL` +
/// `SUPublicEDKey` in Info.plist and points them at a hosted appcast.
///
/// Channels: each channel (stable/beta/nightly) has its **own** appcast feed at the matching git
/// branch's repo root (see `UpdateChannel.feedURL`). The `ChannelDelegate` overrides Sparkle's
/// `SUFeedURL` per the selected channel via `feedURLString(for:)`, so switching channels just points
/// the updater at a different branch's manifest — no cross-branch merging.
@MainActor
@Observable
final class UpdaterController {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private let channelDelegate = ChannelDelegate()

    init(channel: UpdateChannel = .stable) {
        channelDelegate.channel = channel
        // Seed the current channel as available so the picker shows a valid selection immediately;
        // the probe fills in (or removes) the rest.
        availableChannels = [channel]
        // Sparkle requires a code-signed host with a valid feed; starting it in an unsigned/dev
        // build aborts. Only start it in release builds — the dev bundle isn't signed.
        #if !DEBUG
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: channelDelegate, userDriverDelegate: nil)
        #endif
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }
    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Switch the channel; a background information check re-queries the new feed immediately.
    var channel: UpdateChannel = .stable {
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

    /// Sparkle's delegate must be an `NSObject`. It points the updater at the selected channel's feed
    /// (overriding `SUFeedURL`) and reports the allowed channel set (empty — feed selection *is* the
    /// channel with per-branch feeds).
    private final class ChannelDelegate: NSObject, SPUUpdaterDelegate {
        var channel: UpdateChannel = .stable
        func feedURLString(for updater: SPUUpdater) -> String? { channel.feedURL }
        func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel.allowedChannels }
    }
}
