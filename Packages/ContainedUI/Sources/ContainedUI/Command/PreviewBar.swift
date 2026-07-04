import SwiftUI

/// The signature "Reveal CLI" strip: shows the exact `container …` command an action will run,
/// copyable to the clipboard. Drives user trust and learning.
public extension UI.Command {
    struct PreviewBar<Actions: View>: View {
        public let command: [String]
        public var copyHelp: String
        public var copiedAccessibilityLabel: String
        @ViewBuilder public var actions: () -> Actions

        private var rendered: String { (["container"] + command).joined(separator: " ") }

        public init(command: [String],
                    copyHelp: String,
                    copiedAccessibilityLabel: String,
                    @ViewBuilder actions: @escaping () -> Actions) {
            self.command = command
            self.copyHelp = copyHelp
            self.copiedAccessibilityLabel = copiedAccessibilityLabel
            self.actions = actions
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
                actions()
            }
            .padding(.horizontal, UI.Tokens.Space.s)
            .padding(.vertical, UI.Tokens.Space.s)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, shadow: false)
        }
    }
}

public extension UI.Command.PreviewBar where Actions == EmptyView {
    init(command: [String],
         copyHelp: String,
         copiedAccessibilityLabel: String) {
        self.init(command: command,
                  copyHelp: copyHelp,
                  copiedAccessibilityLabel: copiedAccessibilityLabel) {
            EmptyView()
        }
    }
}

#Preview("Command Preview Bar") {
    UI.Command.PreviewBar(command: ["run", "--name", "preview-web", "nginx"],
                          copyHelp: "Copy command",
                          copiedAccessibilityLabel: "Copied") {
        UI.Action.TextButton(title: "Run", systemName: "play.fill", prominence: .prominent) {}
    }
        .padding(UI.Tokens.Space.xl)
        .frame(width: 520)
}
