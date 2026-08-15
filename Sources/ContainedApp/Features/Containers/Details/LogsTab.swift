import SwiftUI
import ContainedUI
import ContainedCore

/// Live container logs via `container logs --follow`. The stream is tied to this view's lifetime
/// (`.task(id:)`), so leaving the tab cancels it and terminates the child process (SIGTERM).
struct LogsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot
    let headerActions: ContainerPageHeaderActions

    @State private var streamBuffer = UI.Console.StreamBuffer(capacity: 5_000)
    @State private var following = true
    @State private var streaming = false
    @State private var failed: String?

    private let bottomID = "logs-bottom"

    var body: some View {
        ContainerToolTabScaffold {
            controls
        } content: {
            logBody
        }
        // Stream is tied to the view's lifetime and the container id: switching tabs or containers
        // cancels it, terminating the child process (SIGTERM via the stream's onTermination).
        .task(id: snapshot.scopedID) { await stream() }
        .onAppear { updateHeaderActions() }
        .onDisappear { headerActions.clear(for: .logs) }
        .onChange(of: following) { _, _ in updateHeaderActions() }
        .onChange(of: streamBuffer.publicationCount) { _, _ in updateHeaderActions() }
    }

    private var controls: some View {
        HStack(spacing: UI.Layout.Spacing.m) {
            if streaming {
                UI.State.InlineStatus(AppText.string("logs.streaming", defaultValue: "streaming"), isWorking: true)
            }
            Spacer()
            Text(AppText.lineCount(streamBuffer.output.lineCount)).designSecondaryCaption().monospacedDigit()
        }
    }

    private func updateHeaderActions() {
        let copyText = streamBuffer.output.copyText
        let hasOutput = streamBuffer.output.lineCount > 0
        headerActions.replace(for: .logs, with: [
            UI.Action.Item(systemName: "arrow.down.to.line",
                           help: AppText.follow,
                           tint: following ? .accentColor : nil) {
                following.toggle()
            },
            UI.Action.Item(systemName: "doc.on.doc",
                           help: AppText.copyAll,
                           isEnabled: hasOutput) {
                Platform.copyToPasteboard(copyText)
            },
            UI.Action.Item(systemName: "trash",
                           help: AppText.clear,
                           role: .destructive,
                           isEnabled: hasOutput) {
                streamBuffer.clear()
            },
        ])
    }

    @ViewBuilder
    private var logBody: some View {
        if let failed {
            UI.State.Empty(AppText.string("logs.error.title", defaultValue: "Couldn't read logs"),
                             systemImage: "exclamationmark.triangle",
                             description: failed,
                             tone: .error)
        } else if streamBuffer.output.lineCount == 0 {
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
                        ForEach(streamBuffer.output.blocks) { block in
                            Text(block.text.isEmpty ? " " : block.text)
                                .designMonospacedCaption()
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear.frame(height: UI.Layout.Spacing.hairline).id(bottomID)
                    }
                    .padding(UI.Layout.Spacing.s)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
                .onChange(of: streamBuffer.output.lineCount) { _, _ in
                    if following { proxy.scrollTo(bottomID, anchor: .bottom) }
                }
            }
        }
    }

    private func stream() async {
        guard let client = app.client else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }
        streamBuffer.clear(); failed = nil
        streaming = true
        defer { streaming = false }
        do {
            for try await chunk in client.streamLogs(id: snapshot.id,
                                                     runtimeKind: snapshot.runtimeKind,
                                                     follow: true,
                                                     tail: 500) {
                streamBuffer.enqueue(chunk)
            }
            // Stream ended (process exited): flush any trailing partial line.
            streamBuffer.finish()
        } catch is CancellationError {
            // Expected on tab/container switch — the child process is terminated for us.
            streamBuffer.cancel()
        } catch {
            streamBuffer.finish()
            failed = (error as? Core.Command.Error)?.appDisplayMessage ?? error.appDisplayMessage
        }
    }
}
