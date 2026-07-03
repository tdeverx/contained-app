import SwiftUI

public extension View {
    @ViewBuilder
    func designCardSelectionOverlay(when isSelected: Bool) -> some View {
        overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: UI.Tokens.Radius.card, style: .continuous)
                    .fill(UI.Theme.Material.toolbarHoverFill)
                    .allowsHitTesting(false)
            }
        }
    }
}

#Preview("Card Selection Overlay") {
    VStack(spacing: UI.Tokens.Space.m) {
        Text("Unselected")
            .frame(maxWidth: .infinity)
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
            .designCardSelectionOverlay(when: false)

        Text("Selected")
            .frame(maxWidth: .infinity)
            .padding(UI.Tokens.Space.l)
            .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.card)
            .designCardSelectionOverlay(when: true)
    }
    .padding(UI.Tokens.Space.xl)
    .frame(width: 320)
}
