import SwiftUI

/// A transient error banner: a warning glyph + message on a glass surface, sliding up from the bottom.
/// Used as a bottom overlay to surface a store's `errorMessage` without a blocking alert.
public struct ErrorToast: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.callout).lineLimit(2)
        }
        .padding(.horizontal, DesignTokens.Space.l)
        .padding(.vertical, DesignTokens.Space.m)
        .glassSurface(.regular, cornerRadius: DesignTokens.Radius.control)
        .padding(DesignTokens.Space.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
