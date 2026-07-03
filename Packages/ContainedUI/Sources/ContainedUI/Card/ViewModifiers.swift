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
