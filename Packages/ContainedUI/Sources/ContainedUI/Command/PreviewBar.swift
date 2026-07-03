import SwiftUI

/// The signature "Reveal CLI" strip: shows the exact `container …` command an action will run,
/// copyable to the clipboard. Drives user trust and learning.
public extension UI.Command {
    struct PreviewBar: View {
        public let command: [String]
        public var copyHelp: String
        public var copiedAccessibilityLabel: String

        private var rendered: String { (["container"] + command).joined(separator: " ") }

        public init(command: [String],
                    copyHelp: String,
                    copiedAccessibilityLabel: String) {
            self.command = command
            self.copyHelp = copyHelp
            self.copiedAccessibilityLabel = copiedAccessibilityLabel
        }

        public var body: some View {
            HStack(spacing: UI.Tokens.Space.s) {
                Image(systemName: "terminal")
                    .foregroundStyle(.primary)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(rendered)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .copyable([rendered])
                        .lineLimit(1)
                }
                Spacer(minLength: UI.Tokens.Space.s)
                UI.Copy.Icon(value: rendered, help: copyHelp)
            }
            .padding(.horizontal, UI.Tokens.Space.s)
            .padding(.vertical, UI.Tokens.Space.s)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, shadow: false)
        }
    }
}

#Preview("Command Preview Bar") {
    UI.Command.PreviewBar(command: ["run", "--name", "preview-web", "nginx"],
                          copyHelp: "Copy command",
                          copiedAccessibilityLabel: "Copied")
        .padding(UI.Tokens.Space.xl)
        .frame(width: 520)
}
