import AppKit
import ContainedCore
import ContainedUI
import SwiftTerm
import SwiftUI

/// SwiftTerm is AppKit-backed, so the bridge stays isolated at the platform edge.
struct TerminalSurface: NSViewRepresentable {
    let invocation: Core.Command.Invocation
    var onExit: (Int32?) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onExit: onExit) }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        makeTerminalView(coordinator: context.coordinator)
    }

    func makeTerminalView(coordinator: Coordinator) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = coordinator
        view.font = NSFont.monospacedSystemFont(ofSize: UI.Console.Metric.fontSize, weight: .regular)
        view.nativeBackgroundColor = .clear
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
        // A disconnected session must not mark its replacement as ended.
        nsView.processDelegate = nil
        nsView.terminate()
        // SwiftTerm owns child reaping/escalation when the view releases its process.
        // Committed GPU work can briefly delay permanent renderer shutdown.
        if !nsView.updateUiClosed() {
            Task { @MainActor in
                while !nsView.updateUiClosed() {
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
        }
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onExit: (Int32?) -> Void
        init(onExit: @escaping (Int32?) -> Void) { self.onExit = onExit }

        func processTerminated(source: TerminalView, exitCode: Int32?) { onExit(exitCode) }
        func processFailedToStart(source: TerminalView, error: LocalProcessError) { onExit(nil) }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
