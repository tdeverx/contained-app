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

    /// Sparkle's delegate must be an `NSObject`. It points the updater at the selected channel's feed
    /// (overriding `SUFeedURL`) and reports the allowed channel set (empty — feed selection *is* the
    /// channel with per-branch feeds).
    private final class ChannelDelegate: NSObject, SPUUpdaterDelegate {
        var channel: UpdateChannel = .stable
        func feedURLString(for updater: SPUUpdater) -> String? { channel.feedURL }
        func allowedChannels(for updater: SPUUpdater) -> Set<String> { channel.allowedChannels }
    }
}
