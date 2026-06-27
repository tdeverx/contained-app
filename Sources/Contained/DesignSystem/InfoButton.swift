import SwiftUI

/// A small `info.circle` button that reveals help text in a popover. Replaces hover-only tooltips so
/// the guidance is always discoverable (tap, not hover) and reachable by VoiceOver / keyboard. The
/// popover wraps to as many lines as the text needs (it never truncates) and can be turned off
/// globally in Settings → Appearance.
struct InfoButton: View {
    let text: String
    @Environment(AppModel.self) private var app
    @Environment(\.modalMaterial) private var modalMaterial
    @State private var showing = false

    init(_ text: String) { self.text = text }

    var body: some View {
        if app.settings.showInfoTips {
            Button { showing = true } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(text)                       // hover still works as a bonus for mouse users
            .accessibilityLabel("More info")
            .popover(isPresented: $showing, arrowEdge: .trailing) {
                Text(.init(text))             // Markdown-aware so tips can use **bold** / `code`
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 300)
                    .padding(Tokens.Space.m)
                    .background {
                        VisualEffectBackground(material: modalMaterial.nsMaterial, blendingMode: .withinWindow)
                    }
                    .presentationBackground(.clear)
            }
        }
    }
}

extension View {
    /// Append an info-circle popover to a form row, pinned to the trailing edge (so the icon is
    /// always far-right regardless of the row's own content width). The always-available replacement
    /// for the old hover-only field tips.
    func fieldInfo(_ text: String) -> some View {
        HStack(spacing: Tokens.Space.s) {
            self
            Spacer(minLength: Tokens.Space.s)
            InfoButton(text)
        }
    }
}
