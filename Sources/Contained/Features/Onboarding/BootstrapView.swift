import SwiftUI
import ContainedDesignSystem
import AppKit
import ContainedCore

/// First-run / degraded states: CLI missing, unsupported version, or service stopped — each with
/// the action that resolves it (start service, locate the CLI, continue anyway, try again).
struct BootstrapView: View {
    @Environment(AppModel.self) private var app
    @State private var starting = false

    var body: some View {
        VStack(spacing: Tokens.Space.l) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(title).font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            actions
        }
        .padding(Tokens.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var actions: some View {
        switch app.bootstrap {
        case .serviceStopped:
            Button {
                Task { starting = true; await app.startService(); starting = false }
            } label: {
                Label(starting ? "Starting…" : "Start container service", systemImage: "play.circle")
                    .padding(.horizontal, Tokens.Space.s)
            }
            .buttonStyle(.borderedProminent)
            .disabled(starting)
        case .cliMissing:
            HStack(spacing: Tokens.Space.m) {
                Button { openReleases() } label: { Label("Get the CLI", systemImage: "arrow.down.circle") }
                    .buttonStyle(.borderedProminent)
                Button { locateCLI() } label: { Label("Locate binary…", systemImage: "folder") }
            }
            Button("Try again") { Task { await app.retryBootstrap() } }.buttonStyle(.link)
        case .unsupported:
            HStack(spacing: Tokens.Space.m) {
                Button("Continue anyway") { Task { await app.continueUnsupported() } }
                    .buttonStyle(.borderedProminent)
                Button("Try again") { Task { await app.retryBootstrap() } }
            }
        case .checking:
            ProgressView()
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
        panel.message = "Select the `container` binary"
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
        case .serviceStopped: return "Container service is stopped"
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
            return "Start the service to manage containers, images, and more."
        case .checking:
            return "Talking to the container service."
        case .ready:
            return ""
        }
    }
}
