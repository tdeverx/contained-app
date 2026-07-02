import SwiftUI

public struct StatusDot: View {
    public var color: Color
    public var size: CGFloat

    public init(color: Color, size: CGFloat = UI.Tokens.IconSize.statusDot) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

public struct StatusBadge: View {
    public var text: String
    public var tint: Color
    public var font: Font

    public init(text: String,
                tint: Color,
                font: Font = .caption.weight(.medium)) {
        self.text = text
        self.tint = tint
        self.font = font
    }

    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(tint)
            .padding(.horizontal, UI.Tokens.Badge.horizontalPadding)
            .padding(.vertical, UI.Tokens.Badge.verticalPadding)
            .background(tint.opacity(UI.Tokens.Badge.statusOpacity), in: Capsule())
    }
}
