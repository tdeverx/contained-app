import SwiftUI

/// The signature "Reveal CLI" strip: shows the exact `container …` command an action will run,
/// copyable to the clipboard. Drives user trust and learning.
public struct CommandPreviewBar: View {
    public let command: [String]
    public var copyHelp: String
    public var copiedAccessibilityLabel: String
    @State private var copied = false

    private var rendered: String { (["container"] + command).joined(separator: " ") }

    public init(command: [String],
                copyHelp: String,
                copiedAccessibilityLabel: String) {
        self.command = command
        self.copyHelp = copyHelp
        self.copiedAccessibilityLabel = copiedAccessibilityLabel
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "terminal")
                .foregroundStyle(.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(rendered)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            Spacer(minLength: Tokens.Space.s)
            Button {
                copyToPasteboard(rendered)
                withAnimation { copied = true }
                Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { copied = false } }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(copyHelp)
            .accessibilityLabel(copied ? copiedAccessibilityLabel : copyHelp)
        }
        .padding(.horizontal, Tokens.Space.s)
        .padding(.vertical, Tokens.Space.s)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.card, shadow: false)
    }
}
