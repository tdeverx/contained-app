import SwiftUI
import Sparkle

/// Thin wrapper over Sparkle's standard updater. Inert until a signed build sets `SUFeedURL` +
/// `SUPublicEDKey` in Info.plist and points them at a hosted appcast (see scripts/appcast.sh).
///
/// Channels: a single appcast carries stable (un-tagged), `beta`, and `nightly` items; the
/// `ChannelDelegate` tells Sparkle which channels the user opted into via `allowedChannels(for:)`.
@MainActor
@Observable
final class UpdaterController {
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private let channelDelegate = ChannelDelegate()

    init(channel: UpdateChannel = .stable) {
        channelDelegate.allowed = channel.allowedChannels
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

    /// Switch the opted-in channel set; a background information check picks it up immediately.
    var channel: UpdateChannel = .stable {
        didSet {
            channelDelegate.allowed = channel.allowedChannels
            controller?.updater.checkForUpdateInformation()
        }
    }

    /// Sparkle's delegate must be an `NSObject`; it just reports the allowed channel set.
    private final class ChannelDelegate: NSObject, SPUUpdaterDelegate {
        var allowed: Set<String> = []
        func allowedChannels(for updater: SPUUpdater) -> Set<String> { allowed }
    }
}
