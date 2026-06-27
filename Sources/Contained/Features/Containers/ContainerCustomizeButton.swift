import SwiftUI
import ContainedCore

/// Container identity chip that turns into the customization affordance on hover.
struct ContainerCustomizeButton: View {
    let snapshot: ContainerSnapshot
    let style: Personalization

    @State private var hovering = false
    @State private var showingCustomize = false

    var body: some View {
        Button { showingCustomize = true } label: {
            Image(systemName: hovering ? "paintbrush.pointed.fill" : style.symbol)
                .font(.system(size: 15))
                .foregroundStyle(style.color)
                .frame(width: Tokens.IconSize.chip, height: Tokens.IconSize.chip)
                .background(style.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Customize card")
        .accessibilityLabel("Customize \(style.displayName(fallback: snapshot.id))")
        .popover(isPresented: $showingCustomize, arrowEdge: .trailing) {
            CustomizeSheet(snapshot: snapshot)
        }
    }
}
