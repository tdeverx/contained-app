import SwiftUI

/// The circular glass ellipsis menu used as the trailing accessory on every resource row
/// (Images/Volumes/Networks/Registries/Stacks) and the detail header. Centralizes the styling
/// chain and the VoiceOver label so icon-only menus are consistently accessible.
struct GlassRowMenu<Content: View>: View {
    var systemImage: String = "ellipsis"
    var accessibilityLabel: String = "Options"
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: Tokens.IconSize.rowMenu, height: Tokens.IconSize.rowMenu)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(accessibilityLabel)
    }
}
