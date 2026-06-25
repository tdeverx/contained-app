import SwiftUI

/// A small `info.circle` button that reveals help text in a popover. Replaces hover-only tooltips so
/// the guidance is always discoverable (tap, not hover) and reachable by VoiceOver / keyboard.
struct InfoButton: View {
    let text: String
    @State private var showing = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(text)                       // hover still works as a bonus for mouse users
        .accessibilityLabel("More info")
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            Text(text)
                .font(.callout)
                .padding(Tokens.Space.m)
                .frame(maxWidth: 280)
        }
    }
}

extension View {
    /// Append an info-circle popover to a form row (the always-available replacement for the old
    /// hover-only field tips).
    func fieldInfo(_ text: String) -> some View {
        HStack(spacing: Tokens.Space.s) {
            self
            InfoButton(text)
        }
    }
}
