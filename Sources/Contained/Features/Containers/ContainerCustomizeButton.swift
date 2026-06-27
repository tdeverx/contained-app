import SwiftUI
import ContainedCore

/// Container identity chip that turns into the customization affordance on hover. The customize
/// popover is owned by `ContainerCard` and anchored to the whole card (not this chip), so the live
/// card itself serves as the preview — this button just triggers it.
struct ContainerCustomizeButton: View {
    let snapshot: ContainerSnapshot
    let style: Personalization
    var onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
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
    }
}
