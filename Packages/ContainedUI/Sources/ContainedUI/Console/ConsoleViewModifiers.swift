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

#Preview("Terminal Surface Chrome") {
    Text("preview-web$ nginx -g 'daemon off;'")
        .font(.system(.caption, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .terminalSurfaceChrome()
        .padding(UI.Tokens.Space.xl)
        .frame(width: 420)
}
