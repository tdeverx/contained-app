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
            ResourceCardIconChip(symbol: hovering ? "paintbrush.pointed.fill" : style.symbol,
                                 tint: style.color)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Customize card")
        .accessibilityLabel("Customize \(style.displayName(fallback: snapshot.id))")
    }
}
