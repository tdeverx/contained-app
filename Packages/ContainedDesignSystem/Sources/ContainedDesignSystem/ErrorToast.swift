import SwiftUI

/// A transient error banner: a warning glyph + message on a glass surface, sliding up from the bottom.
/// Used as a bottom overlay to surface a store's `errorMessage` without a blocking alert.
public struct ErrorToast: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.callout).lineLimit(2)
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .glassSurface(.regular, cornerRadius: Tokens.Radius.control)
        .padding(Tokens.Space.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
