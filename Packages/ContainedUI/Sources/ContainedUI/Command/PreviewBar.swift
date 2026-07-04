import SwiftUI

/// The signature "Reveal CLI" strip: shows the exact runtime command an action will run,
/// copyable to the clipboard. Drives user trust and learning.
public extension UI.Command {
    struct PreviewBar<Actions: View>: View {
        public let commandText: String
        public var copyHelp: String
        public var copiedAccessibilityLabel: String
        @ViewBuilder public var actions: () -> Actions

        public init(commandText: String,
                    copyHelp: String,
                    copiedAccessibilityLabel: String,
                    @ViewBuilder actions: @escaping () -> Actions) {
            self.commandText = commandText
            self.copyHelp = copyHelp
            self.copiedAccessibilityLabel = copiedAccessibilityLabel
            self.actions = actions
        }

        public var body: some View {
            HStack(spacing: UI.Tokens.Space.s) {
                Image(systemName: "terminal")
                    .foregroundStyle(.primary)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(commandText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .copyable([commandText])
                        .lineLimit(1)
                }
                Spacer(minLength: UI.Tokens.Space.s)
                UI.Copy.Icon(value: commandText, help: copyHelp)
                actions()
            }
            .padding(.horizontal, UI.Tokens.Space.s)
            .padding(.vertical, UI.Tokens.Space.s)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card, shadow: false)
        }
    }
}

public extension UI.Command.PreviewBar where Actions == EmptyView {
    init(commandText: String,
         copyHelp: String,
         copiedAccessibilityLabel: String) {
        self.init(commandText: commandText,
                  copyHelp: copyHelp,
                  copiedAccessibilityLabel: copiedAccessibilityLabel) {
            EmptyView()
        }
    }
}

#Preview("Command Preview Bar") {
    UI.Command.PreviewBar(commandText: "container run --name preview-web nginx",
                          copyHelp: "Copy command",
                          copiedAccessibilityLabel: "Copied") {
        UI.Action.TextButton(title: "Run", systemName: "play.fill", prominence: .prominent) {}
    }
        .padding(UI.Tokens.Space.xl)
        .frame(width: 520)
}
