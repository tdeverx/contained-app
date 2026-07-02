import SwiftUI
import ContainedUI
import ContainedCore

/// Live container logs via `container logs --follow`. The stream is tied to this view's lifetime
/// (`.task(id:)`), so leaving the tab cancels it and terminates the child process (SIGTERM).
struct LogsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: ContainerSnapshot

    @State private var lines: [String] = []
    @State private var carry = ""
    @State private var following = true
    @State private var streaming = false
    @State private var failed: String?

    private let maxLines = 5000
    private let bottomID = "logs-bottom"

    var body: some View {
        ContainerToolTabScaffold {
            controls
        } content: {
            logBody
        }
        // Stream is tied to the view's lifetime and the container id: switching tabs or containers
        // cancels it, terminating the child process (SIGTERM via the stream's onTermination).
        .task(id: snapshot.id) { await stream() }
    }

    private var controls: some View {
        HStack(spacing: UI.Layout.Spacing.m) {
            UI.Action.ToggleButton(isOn: $following, title: AppText.follow, systemName: "arrow.down.to.line")
            if streaming {
                UI.State.InlineStatus(AppText.string("logs.streaming", defaultValue: "streaming"), isWorking: true)
            }
            Spacer()
            Text(AppText.lineCount(lines.count)).designSecondaryCaption().monospacedDigit()
            UI.Action.Group(UI.Action.Item(systemName: "doc.on.doc", help: AppText.copyAll) {
                    copyToPasteboard(lines.joined(separator: "\n"))
            })
            UI.Action.Group(UI.Action.Item(systemName: "trash",
                                           help: AppText.clear,
                                           role: .destructive,
                                           isEnabled: !lines.isEmpty) {
                    lines.removeAll(); carry = ""
            })
        }
    }

    @ViewBuilder
    private var logBody: some View {
        if let failed {
            UI.State.Empty(AppText.string("logs.error.title", defaultValue: "Couldn't read logs"),
                             systemImage: "exclamationmark.triangle",
                             description: failed,
                             tone: .error)
        } else if lines.isEmpty {
            UI.State.Empty(streaming
                                ? AppText.string("logs.waiting", defaultValue: "Waiting for output")
                                : AppText.string("logs.empty", defaultValue: "No output"),
                             systemImage: streaming ? "dot.radiowaves.left.and.right" : "text.alignleft",
                             description: streaming
                                ? AppText.string("logs.waiting.description", defaultValue: "Streaming - this container hasn't logged anything yet.")
                                : AppText.string("logs.empty.description", defaultValue: "This container hasn't produced any logs."))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.hairline) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .designMonospacedCaption()
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear.frame(height: UI.Layout.Spacing.hairline).id(bottomID)
                    }
                    .padding(UI.Layout.Spacing.s)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
                .onChange(of: lines.count) { _, _ in
                    if following { proxy.scrollTo(bottomID, anchor: .bottom) }
                }
            }
        }
    }

    private func stream() async {
        guard let client = app.client else { return }
        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        lines.removeAll(); carry = ""; failed = nil
        streaming = true
        defer { streaming = false }
        do {
            for try await chunk in client.streamLogs(id: snapshot.id, follow: true, tail: 500) {
                ingest(chunk)
            }
            // Stream ended (process exited): flush any trailing partial line.
            if !carry.isEmpty { lines.append(carry); carry = "" }
        } catch is CancellationError {
            // Expected on tab/container switch — the child process is terminated for us.
        } catch {
            failed = (error as? CommandError)?.appDisplayMessage ?? error.appDisplayMessage
        }
    }

    private func ingest(_ chunk: String) {
        let combined = carry + chunk
        guard let lastNewline = combined.lastIndex(of: "\n") else { carry = combined; return }
        let complete = combined[..<lastNewline]
        carry = String(combined[combined.index(after: lastNewline)...])
        lines.append(contentsOf: complete.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
    }
}
