import SwiftUI

/// The circular glass ellipsis menu used as the trailing accessory on every resource row
/// (Images/Volumes/Networks/Registries/Templates) and the detail header. Centralizes the styling
/// chain and the VoiceOver label so icon-only menus are consistently accessible.
public struct GlassRowMenu<Content: View>: View {
    public var systemImage: String
    public var accessibilityLabel: String
    @ViewBuilder public var content: () -> Content

    public init(systemImage: String = "ellipsis",
                accessibilityLabel: String,
                @ViewBuilder content: @escaping () -> Content) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.content = content
    }

    public var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
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
