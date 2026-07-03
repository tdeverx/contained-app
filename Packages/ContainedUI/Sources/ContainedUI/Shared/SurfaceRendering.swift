import SwiftUI

enum SharedSurfaceRendering {
    static func fillStyle(color: Color,
                          opacity: Double,
                          gradient: Bool,
                          gradientAngle: Double) -> AnyShapeStyle {
        guard gradient else { return AnyShapeStyle(color.opacity(opacity)) }
        let radians = gradientAngle * .pi / 180
        let dx = cos(radians) / 2
        let dy = sin(radians) / 2
        return AnyShapeStyle(LinearGradient(
            colors: [color.opacity(opacity * 1.35), color.opacity(opacity * 0.4)],
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
    }

    static func shadowColor(for colorScheme: ColorScheme, scale: Double = 1) -> Color {
        let base = colorScheme == .dark ? 0.55 : 0.18
        return .black.opacity(base * scale)
    }
}
