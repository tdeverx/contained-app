import AppKit
import ContainedCore
import ContainedUI
import Darwin
import SwiftTerm
import SwiftUI

/// SwiftTerm is AppKit-backed, so the bridge stays isolated at the platform edge.
struct TerminalSurface: NSViewRepresentable {
    let invocation: Core.Command.Invocation
    var onExit: (Int32?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        view.font = NSFont.monospacedSystemFont(ofSize: UI.Console.Metric.fontSize, weight: .regular)
        view.nativeBackgroundColor = NSColor.black.withAlphaComponent(UI.Console.Metric.nativeBackgroundOpacity)
        view.nativeForegroundColor = NSColor(white: UI.Console.Metric.nativeForegroundWhite, alpha: 1)

        // PTY is provided by SwiftTerm; the command builder requests a TTY inside the container.
        // Inherit the host environment so runtime CLIs can find their normal data directories.
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["COLORTERM"] = "truecolor"
        view.startProcess(executable: invocation.executableURL.path,
                          args: invocation.arguments,
                          environment: env.map { "\($0.key)=\($0.value)" },
                          execName: nil)
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
