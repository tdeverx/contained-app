import SwiftUI

public extension View {
    func terminalSurfaceChrome() -> some View {
        padding(UI.Tokens.Space.s)
            .background(.black.opacity(UI.Tokens.Terminal.surfaceOpacity),
                        in: RoundedRectangle(cornerRadius: UI.Tokens.Radius.card,
                                             style: .continuous))
            .padding(UI.Tokens.Space.s)
    }
}
