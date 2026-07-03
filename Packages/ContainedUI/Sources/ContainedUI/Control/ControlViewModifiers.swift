import SwiftUI

public extension View {
    func subtleTileBackground() -> some View {
        background(.quaternary.opacity(UI.Tokens.InlineControl.subtleTileOpacity),
                   in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.control,
                                        style: .continuous))
    }

    func toolbarControlContentShape() -> some View {
        contentShape(Capsule(style: .continuous))
    }
}

#Preview("Control Modifiers") {
    HStack(spacing: UI.Tokens.Space.m) {
        Text("Subtle tile")
            .padding(UI.Tokens.Space.m)
            .subtleTileBackground()

        Image(systemName: "slider.horizontal.3")
            .padding(UI.Tokens.Space.m)
            .materialCapsuleSurface(shadow: false)
            .toolbarControlContentShape()
    }
    .padding(UI.Tokens.Space.xl)
}
