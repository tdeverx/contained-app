import SwiftUI

/// Centralized Liquid Glass surface: real `.glassEffect()` plus a soft shadow that lifts the
/// element off the backdrop, and an optional colored (optionally gradient) wash behind the glass.
struct GlassSurface: ViewModifier {
    enum Level { case regular, thin, ultraThin }
    var level: Level = .regular
    var cornerRadius: CGFloat = Tokens.Radius.card
    var glass: Glass = .regular
    /// Lift the surface off the backdrop with a soft shadow. Pass `false` for flat tiles that sit
    /// inside an already-elevated panel (e.g. cards in the toolbar morph panels / the creation menu).
    var shadow: Bool = true
    var fill: Color? = nil
    var fillOpacity: Double = 0.18
    var gradient: Bool = false
    var gradientAngle: Double = 135

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // Layering, back → front: tint wash → glass → content.
        // `.glassEffect` puts the glass *behind* the content; the tint sits behind the glass so it
        // shows *through* it (refracted), rather than washing over the content.
        // NOTE: no `.compositingGroup()` here — it rasterizes the glass and makes it render opaque,
        // breaking the live translucency. `.glassEffect` provides its own elevation.
        return content
            .clipShape(shape)
            .background {
                if shadow {
                    ExteriorShadow(cornerRadius: cornerRadius,
                                   color: shadowColor,
                                   radius: shadowRadius,
                                   y: shadowY)
                }
            }
            .glassEffect(glass, in: shape)
            .background {
                if let fill {
                    shape.fill(fillStyle(fill))
                }
            }
    }

    private func fillStyle(_ color: Color) -> AnyShapeStyle {
        if gradient {
            let radians = gradientAngle * .pi / 180
            let dx = cos(radians) / 2
            let dy = sin(radians) / 2
            return AnyShapeStyle(LinearGradient(
                colors: [color.opacity(fillOpacity * 1.35), color.opacity(fillOpacity * 0.4)],
                startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
        }
        return AnyShapeStyle(color.opacity(fillOpacity))
    }

    private var shadowColor: Color {
        let base = colorScheme == .dark ? 0.55 : 0.18
        let scale: Double
        switch level {
        case .regular: scale = 1.0
        case .thin: scale = 0.6
        case .ultraThin: scale = 0.4
        }
        return .black.opacity(base * scale)
    }

    private var shadowRadius: CGFloat {
        switch level { case .regular: return 10; case .thin: return 6; case .ultraThin: return 4 }
    }
    private var shadowY: CGFloat {
        switch level { case .regular: return 4; case .thin: return 2; case .ultraThin: return 1 }
    }
}

extension View {
    func glassSurface(_ level: GlassSurface.Level = .regular,
                      cornerRadius: CGFloat = Tokens.Radius.card,
                      glass: Glass = .regular,
                      shadow: Bool = true,
                      fill: Color? = nil,
                      fillOpacity: Double = 0.18,
                      gradient: Bool = false,
                      gradientAngle: Double = 135) -> some View {
        modifier(GlassSurface(level: level, cornerRadius: cornerRadius, glass: glass,
                              shadow: shadow, fill: fill, fillOpacity: fillOpacity, gradient: gradient,
                              gradientAngle: gradientAngle))
    }
}
