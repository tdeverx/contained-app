import SwiftUI
import ContainedDesignSystem
import ContainedCore
import ContainedRuntime

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
        HStack(spacing: Tokens.Space.m) {
            DesignGlassToggle(isOn: $following, title: "Follow", systemName: "arrow.down.to.line")
            if streaming {
                HStack(spacing: Tokens.Toolbar.searchIconGap) {
                    ProgressView().controlSize(.small)
                    Text("streaming").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(lines.count) lines").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            DesignActionGroup(DesignAction(systemName: "doc.on.doc", help: "Copy all") {
                    copyToPasteboard(lines.joined(separator: "\n"))
            })
            DesignActionGroup(DesignAction(systemName: "trash",
                                           help: "Clear",
                                           role: .destructive,
                                           isEnabled: !lines.isEmpty) {
                    lines.removeAll(); carry = ""
            })
        }
    }

    @ViewBuilder
    private var logBody: some View {
        if let failed {
            ContentUnavailableView {
                Label("Couldn't read logs", systemImage: "exclamationmark.triangle")
            } description: { Text(failed) }
        } else if lines.isEmpty {
            // Before any output: "connecting" while the stream is live, "no output" once it ended.
            ContentUnavailableView {
                Label(streaming ? "Waiting for output" : "No output",
                      systemImage: streaming ? "dot.radiowaves.left.and.right" : "text.alignleft")
            } description: {
                Text(streaming ? "Streaming — this container hasn't logged anything yet."
                               : "This container hasn't produced any logs.")
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.hairline) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear.frame(height: Tokens.Space.hairline).id(bottomID)
                    }
                    .padding(Tokens.Space.s)
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
            failed = (error as? CommandError)?.userMessage ?? error.localizedDescription
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
