import SwiftUI
import ContainedDesignSystem
import AppKit
import SwiftTerm
import ContainedCore
import Darwin

/// An interactive shell inside a running container, via `container exec -it <id> <shell>`.
///
/// AppKit bridge (flagged per the build rule): SwiftTerm is a mature, AppKit-backed VT100/xterm
/// emulator wrapped through `NSViewRepresentable`. Re-implementing a correct terminal from scratch
/// in SwiftUI would be the single riskiest component, so we use SwiftTerm — the same choice locked
/// in the plan. Only the terminal surface touches AppKit; everything around it stays SwiftUI.
struct TerminalTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot

    /// A finished session's exit code (boxed so `nil`-the-state differs from a `nil` exit code).
    private struct Ended: Equatable { let code: Int32? }

    @State private var shell = "/bin/sh"
    @State private var session = 0          // bump to force a fresh terminal (reconnect / shell change)
    @State private var ended: Ended?        // nil = live; non-nil = process ended

    private let shells = ["/bin/sh", "/bin/bash", "/bin/ash", "/bin/zsh"]

    var body: some View {
        if snapshot.state != .running {
            ContentUnavailableView {
                Label("Not running", systemImage: "terminal")
            } description: {
                Text("Start the container to open a shell.")
            }
        } else if let url = app.cliURL {
            ContainerToolTabScaffold {
                controls
            } content: {
                ZStack {
                    TerminalSurface(executableURL: url, containerID: snapshot.id, shell: shell) { code in
                        ended = Ended(code: code)
                    }
                    // Recreating the view tears down the old exec. Include container/shell so rapid
                    // card switches cannot reuse a terminal process for a different target.
                    .id("\(snapshot.id)-\(shell)-\(session)")
                    .terminalSurfaceChrome()
                    if let ended {
                        endedOverlay(code: ended.code)
                    }
                }
            }
        } else {
            ContentUnavailableView("Terminal unavailable", systemImage: "terminal",
                                   description: Text("The container CLI path couldn't be resolved."))
        }
    }

    private var controls: some View {
        HStack(spacing: Tokens.Space.m) {
            Picker("Shell", selection: $shell) {
                ForEach(shells, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: Tokens.FormWidth.shellPicker)
            .onChange(of: shell) { _, _ in reconnect() }
            Text("exec into \(snapshot.id)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            DesignActionGroup(DesignAction(systemName: "arrow.clockwise", help: AppText.reconnect) { reconnect() })
        }
    }

    private func endedOverlay(code: Int32?) -> some View {
        ResourceCardInsetSection(alignment: .center, padding: Tokens.Space.xl) {
            Image(systemName: "bolt.horizontal.circle").font(.largeTitle).foregroundStyle(.secondary)
            Text(code == nil || code == 0 ? "Session ended" : "Session ended (exit \(code!))")
                .font(.headline)
            DesignActionGroup(DesignAction(systemName: "arrow.clockwise",
                                           title: "Reconnect",
                                           help: AppText.reconnectTerminal,
                                           action: reconnect))
        }
    }

    private func reconnect() {
        ended = nil
        session += 1
    }
}

/// `NSViewRepresentable` wrapper around SwiftTerm's `LocalProcessTerminalView`, which owns the PTY
/// and child process. Tearing down the view (`dismantleNSView`) terminates the `exec` child and
/// escalates stale `container exec --tty` children that do not exit from SwiftTerm's SIGTERM.
struct TerminalSurface: NSViewRepresentable {
    let executableURL: URL
    let containerID: String
    let shell: String
    var onExit: (Int32?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.font = NSFont.monospacedSystemFont(ofSize: Tokens.Terminal.fontSize, weight: .regular)
        view.nativeBackgroundColor = NSColor.black.withAlphaComponent(Tokens.Terminal.nativeBackgroundOpacity)
        view.nativeForegroundColor = NSColor(white: Tokens.Terminal.nativeForegroundWhite, alpha: 1)

        // `container exec -i -t <id> <shell>` — PTY is provided by SwiftTerm; -t requests a TTY
        // inside the container, -i keeps stdin attached. We must inherit the *host* environment
        // (notably HOME) so the `container` CLI can find its data dir — SwiftTerm's nil-default env
        // is too sparse and the exec would silently fail to connect. TERM/LANG drive the emulator.
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["COLORTERM"] = "truecolor"
        view.startProcess(executable: executableURL.path,
                          args: ["exec", "--interactive", "--tty", containerID, shell],
                          environment: env.map { "\($0.key)=\($0.value)" }, execName: nil)
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        let pid = nsView.process?.shellPid ?? 0
        nsView.terminate()
        TerminalProcessReaper.terminate(pid)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onExit: (Int32?) -> Void
        init(onExit: @escaping (Int32?) -> Void) { self.onExit = onExit }

        func processTerminated(source: TerminalView, exitCode: Int32?) { onExit(exitCode) }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}

private enum TerminalProcessReaper {
    static func terminate(_ pid: pid_t) {
        guard pid > 0 else { return }
        kill(pid, SIGTERM)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.7) {
            guard kill(pid, 0) == 0 else { return }
            kill(pid, SIGKILL)
        }
    }
}
