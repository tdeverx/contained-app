import SwiftUI

/// A small `info.circle` button that reveals help text in a popover. Replaces hover-only tooltips so
/// the guidance is always discoverable (tap, not hover) and reachable by VoiceOver / keyboard. The
/// popover wraps to as many lines as the text needs (it never truncates) and can be turned off
/// globally in Settings → Appearance.
struct InfoButton: View {
    let text: String
    var visible = true
    @Environment(AppModel.self) private var app
    @Environment(\.modalMaterial) private var modalMaterial
    @State private var showing = false

    init(_ text: String, visible: Bool = true) {
        self.text = text
        self.visible = visible
    }

    var body: some View {
        if app.settings.showInfoTips {
            Button { showing = true } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(visible || showing ? 1 : 0)
            .allowsHitTesting(visible || showing)
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
