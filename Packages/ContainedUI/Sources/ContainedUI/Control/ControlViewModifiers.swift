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
