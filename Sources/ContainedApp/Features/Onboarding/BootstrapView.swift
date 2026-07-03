import SwiftUI
import ContainedUI
import AppKit
import ContainedCore

/// First-run / degraded states: CLI missing, unsupported version, or service stopped — each with
/// the action that resolves it (start service, locate the CLI, continue anyway, try again).
struct BootstrapView: View {
    @Environment(AppModel.self) private var app
    @State private var starting = false

    var body: some View {
        UI.State.Hero(systemImage: icon, title: title, message: message) {
            actions
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch app.bootstrap {
        case .serviceStopped:
            if app.appleRuntimeAvailable {
                UI.Action.TextButton(title: starting ? AppText.string("bootstrap.starting", defaultValue: "Starting...") : AppText.string("bootstrap.startService", defaultValue: "Start container service"),
                                       systemName: "play.circle",
                                       prominence: .prominent,
                                       isEnabled: !starting) {
                    Task { starting = true; await app.startService(); starting = false }
                }
            } else {
                HStack(spacing: UI.Layout.Spacing.m) {
                    UI.Action.TextButton(title: AppText.string("common.tryAgain", defaultValue: "Try again"),
                                           systemName: "arrow.clockwise",
                                           prominence: .prominent) {
                        Task { await app.retryBootstrap() }
                    }
                }
            }
        case .cliMissing:
            HStack(spacing: UI.Layout.Spacing.m) {
                UI.Action.TextButton(title: AppText.string("bootstrap.getCLI", defaultValue: "Get the CLI"),
                                       systemName: "arrow.down.circle",
                                       prominence: .prominent,
                                       action: openReleases)
                UI.Action.TextButton(title: AppText.string("bootstrap.locateBinary", defaultValue: "Locate binary..."),
                                       systemName: "folder",
                                       action: locateCLI)
            }
            UI.Action.TextButton(title: AppText.string("common.tryAgain", defaultValue: "Try again"),
                                   systemName: "arrow.clockwise") {
                Task { await app.retryBootstrap() }
            }
        case .unsupported:
            HStack(spacing: UI.Layout.Spacing.m) {
                UI.Action.TextButton(title: AppText.string("bootstrap.continueAnyway", defaultValue: "Continue anyway"),
                                       systemName: "arrow.right",
                                       prominence: .prominent) {
                    Task { await app.continueUnsupported() }
                }
                UI.Action.TextButton(title: AppText.string("common.tryAgain", defaultValue: "Try again"),
                                       systemName: "arrow.clockwise") {
                    Task { await app.retryBootstrap() }
                }
            }
        case .checking:
            UI.State.ProgressIndicator()
        case .ready:
            EmptyView()
        }
    }

    private func openReleases() {
        if let url = URL(string: "https://github.com/apple/container/releases") { NSWorkspace.shared.open(url) }
    }

    private func locateCLI() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = AppText.selectContainerBinary
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await app.useCLIPath(url.path) }
        }
    }

    private var icon: String {
        switch app.bootstrap {
        case .cliMissing: return "exclamationmark.triangle"
        case .unsupported: return "exclamationmark.circle"
        case .serviceStopped: return "powersleep"
        default: return "cube"
        }
    }
    private var title: String {
        switch app.bootstrap {
        case .cliMissing: return "Container CLI not found"
        case .unsupported(let v): return "Unsupported version (\(v))"
        case .serviceStopped:
            return app.appleRuntimeAvailable
                ? "Container service is stopped"
                : "Docker endpoint is unavailable"
        case .checking: return "Connecting…"
        case .ready: return "Ready"
        }
    }
    private var message: String {
        switch app.bootstrap {
        case .cliMissing:
            return "Install Apple's container tool, or set its path in Settings. Looked in /usr/local/bin and /opt/homebrew/bin."
        case .unsupported:
            return "Contained targets container 1.0.x. Some features may not work with this version."
        case .serviceStopped:
            return app.appleRuntimeAvailable
                ? "Start the service to manage containers, images, and more."
                : "Start Docker externally, then retry the connection."
        case .checking:
            return "Talking to the container service."
        case .ready:
            return ""
        }
    }
}
