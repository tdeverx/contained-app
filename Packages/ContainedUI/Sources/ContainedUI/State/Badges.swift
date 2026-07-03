import SwiftUI

public extension UI.Badge {
struct Dot: View {
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

struct Status: View {
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
        SharedCapsuleLabel(horizontalPadding: UI.Tokens.Badge.horizontalPadding,
                           verticalPadding: UI.Tokens.Badge.verticalPadding,
                           foreground: AnyShapeStyle(tint),
                           fill: AnyShapeStyle(tint.opacity(UI.Tokens.Badge.statusOpacity))) {
            SwiftUI.Text(text)
                .font(font)
        }
    }
}
}

#Preview("Badges") {
    HStack(spacing: UI.Tokens.Space.m) {
        UI.Badge.Dot(color: .green)
        UI.Badge.Status(text: "Running", tint: .green)
        UI.Badge.Status(text: "Failed", tint: .red)
    }
    .padding(UI.Tokens.Space.xl)
}
