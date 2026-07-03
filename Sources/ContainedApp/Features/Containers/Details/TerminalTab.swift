import SwiftUI
import ContainedUI
import ContainedCore

/// An interactive shell inside a running container, via `container exec -it <id> <shell>`.
///
/// SwiftTerm hosting lives in `Services/Platform/TerminalSurface.swift`; this tab stays SwiftUI and
/// runtime state only.
struct TerminalTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot

    /// A finished session's exit code (boxed so `nil`-the-state differs from a `nil` exit code).
    private struct Ended: Equatable { let code: Int32? }

    @State private var shell = "/bin/sh"
    @State private var session = 0          // bump to force a fresh terminal (reconnect / shell change)
    @State private var ended: Ended?        // nil = live; non-nil = process ended

    private let shells = ["/bin/sh", "/bin/bash", "/bin/ash", "/bin/zsh"]

    var body: some View {
        if snapshot.state != .running {
            UI.State.Empty(AppText.string("terminal.notRunning", defaultValue: "Not running"),
                             systemImage: "terminal",
                             description: AppText.string("terminal.notRunning.description", defaultValue: "Start the container to open a shell."))
        } else if let client = app.client,
                  let invocation = try? client.terminalInvocation(containerID: snapshot.id,
                                                                 shell: shell,
                                                                 runtimeKind: snapshot.runtimeKind) {
            ContainerToolTabScaffold {
                controls
            } content: {
                ZStack {
                    TerminalSurface(invocation: invocation) { code in
                        ended = Ended(code: code)
                    }
                    // Recreating the view tears down the exec. Include container/shell so rapid
                    // card switches cannot reuse a terminal process for a different target.
                    .id("\(snapshot.scopedID)-\(shell)-\(session)")
                    .terminalSurfaceChrome()
                    if let ended {
                        endedOverlay(code: ended.code)
                    }
                }
            }
        } else {
            UI.State.Empty(AppText.string("terminal.unavailable", defaultValue: "Terminal unavailable"),
                             systemImage: "terminal",
                             description: AppText.string("terminal.unavailable.description", defaultValue: "The container CLI path couldn't be resolved."))
        }
    }

    private var controls: some View {
        HStack(spacing: UI.Layout.Spacing.m) {
            Picker("Shell", selection: $shell) {
                ForEach(shells, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: UI.Form.Width.shellPicker)
            .onChange(of: shell) { _, _ in reconnect() }
            Text(AppText.string("terminal.execInto", defaultValue: "exec into \(snapshot.id)"))
                .designSecondaryCaption()
                .lineLimit(1)
            Spacer()
            UI.Action.Group(UI.Action.Item(systemName: "arrow.clockwise", help: AppText.reconnect) { reconnect() })
        }
    }

    private func endedOverlay(code: Int32?) -> some View {
        UI.Card.InsetSection(alignment: .center, padding: UI.Layout.Spacing.xl) {
            Image(systemName: "bolt.horizontal.circle").designStateIconStyle()
            Text(code == nil || code == 0
                 ? AppText.string("terminal.sessionEnded", defaultValue: "Session ended")
                 : AppText.string("terminal.sessionEndedWithExit", defaultValue: "Session ended (exit \(code!))"))
                .designHeadlineLabelStyle()
            UI.Action.Group(UI.Action.Item(systemName: "arrow.clockwise",
                                           title: AppText.reconnect,
                                           help: AppText.reconnectTerminal,
                                           action: reconnect))
        }
    }

    private func reconnect() {
        ended = nil
        session += 1
    }
}
