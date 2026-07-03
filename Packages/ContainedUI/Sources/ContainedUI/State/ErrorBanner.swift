import SwiftUI

/// A transient error banner: a warning glyph + message on a glass surface, sliding up from the bottom.
/// Used as a bottom overlay to surface caller-supplied error copy without a blocking alert.
public extension UI.State {
struct ErrorBanner: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: UI.Tokens.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.callout).lineLimit(2)
        }
        .padding(.horizontal, UI.Tokens.Space.l)
        .padding(.vertical, UI.Tokens.Space.m)
        .materialSurface(.regular, cornerRadius: UI.Tokens.Radius.control)
        .padding(UI.Tokens.Space.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
}

#Preview("Error Banner") {
    UI.State.ErrorBanner(message: "Docker runtime is not reachable.")
        .padding(UI.Tokens.Space.xl)
        .frame(width: 460)
}
