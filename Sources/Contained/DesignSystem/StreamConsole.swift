import SwiftUI
import ContainedCore

/// A scrolling console that consumes a one-shot streaming command (pull / build `--progress plain`)
/// to completion, auto-scrolling and reporting success/failure. Shared by the pull and build flows.
struct StreamConsole: View {
    /// Factory so the stream starts with the view's `.task` (and cancels on disappear).
    let stream: () -> AsyncThrowingStream<String, Error>
    var onComplete: (Bool) -> Void = { _ in }

    enum RunState: Equatable { case running, done, failed(String) }

    @State private var lines: [String] = []
    @State private var carry = ""
    @State private var state: RunState = .running
    private let maxLines = 8000
    private let bottomID = "console-bottom"

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear.frame(height: 1).id(bottomID)
                    }
                    .padding(Tokens.Space.m)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
                .onChange(of: lines.count) { _, _ in proxy.scrollTo(bottomID, anchor: .bottom) }
            }
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
        }
        .task { await consume() }
    }

    private var statusBar: some View {
        HStack(spacing: Tokens.Space.s) {
            switch state {
            case .running:
                ProgressView().controlSize(.small)
                Text("Working…").foregroundStyle(.secondary)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Completed").foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text(message).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text("\(lines.count) lines").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            GlassButton(singleItem: true) {
                GlassButtonItem(systemName: "doc.on.doc", help: "Copy log") {
                    copyToPasteboard(lines.joined(separator: "\n"))
                }
            }
        }
        .font(.callout)
        .padding(.vertical, Tokens.Space.s)
    }

    private func consume() async {
        do {
            for try await chunk in stream() { ingest(chunk) }
            if !carry.isEmpty { lines.append(carry); carry = "" }
            state = .done
            onComplete(true)
        } catch is CancellationError {
            // View dismissed mid-stream; nothing to report.
        } catch {
            if !carry.isEmpty { lines.append(carry); carry = "" }
            state = .failed((error as? CommandError)?.userMessage ?? error.localizedDescription)
            onComplete(false)
        }
    }

    private func ingest(_ chunk: String) {
        let combined = carry + chunk
        guard let lastNewline = combined.lastIndex(of: "\n") else { carry = combined; return }
        carry = String(combined[combined.index(after: lastNewline)...])
        lines.append(contentsOf: combined[..<lastNewline].split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
    }
}
