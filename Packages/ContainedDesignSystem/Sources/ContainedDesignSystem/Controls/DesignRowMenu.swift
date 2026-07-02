import SwiftUI

/// The circular design-system ellipsis menu used as a trailing accessory on compact rows and
/// detail headers.
/// Centralizes the styling chain and the VoiceOver label so icon-only menus are consistently
/// accessible.
public struct DesignRowMenu<Content: View>: View {
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
                .frame(width: DesignTokens.IconSize.rowMenu, height: DesignTokens.IconSize.rowMenu)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(accessibilityLabel)
    }
}
