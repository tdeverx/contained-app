import SwiftUI

struct ExteriorShadow: View {
    var cornerRadius: CGFloat
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    init(cornerRadius: CGFloat, color: Color, radius: CGFloat, y: CGFloat) {
        self.cornerRadius = cornerRadius
        self.color = color
        self.radius = radius
        self.y = y
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape
                .fill(color)
                .blur(radius: radius)
                .offset(y: y)
            shape
                .fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

public extension UI.Card.Grid {
    /// Elevates a collection of cards as one rendered layer so card shadows cannot draw over
    /// neighboring cards. Individual cards in the collection should disable their own elevation.
    struct Elevation: ViewModifier {
        public init() {}

        public func body(content: Content) -> some View {
            content
                .compositingGroup()
                .shadow(color: UI.Theme.Material.elevatedSurfaceShadow,
                        radius: UI.Theme.Material.elevatedSurfaceShadowRadius,
                        y: UI.Theme.Material.elevatedSurfaceShadowY)
        }
    }
}

#Preview("Exterior Shadow") {
    ZStack {
        ExteriorShadow(cornerRadius: UI.Tokens.Radius.card,
                       color: .black.opacity(0.24),
                       radius: 16,
                       y: 8)
        RoundedRectangle(cornerRadius: UI.Tokens.Radius.card, style: .continuous)
            .fill(.thinMaterial)
    }
    .frame(width: 220, height: 120)
    .padding(UI.Tokens.Space.xl)
}
