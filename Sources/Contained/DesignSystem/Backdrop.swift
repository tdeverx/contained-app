import SwiftUI

/// The subtly animated mesh-gradient backdrop beneath all glass. Honors Reduce Motion and the
/// user's backdrop preference (solid disables animation entirely).
struct Backdrop: View {
    var tint: Color
    var style: BackdropStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        Group {
            switch style {
            case .solid:
                base
            case .mesh:
                meshGradient
            }
        }
        .ignoresSafeArea()
    }

    private var base: Color {
        colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93)
    }

    private var meshGradient: some View {
        let animated = !reduceMotion
        let drift = Float(animated ? phase : 0)
        let points: [SIMD2<Float>] = [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(0.5 + 0.08 * drift, 0.5 - 0.06 * drift), SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
        ]
        // A gentle colored field so clear glass surfaces have something to refract.
        let strong = tint.opacity(colorScheme == .dark ? 0.30 : 0.22)
        let soft = tint.opacity(colorScheme == .dark ? 0.16 : 0.12)
        let b = base
        let colors: [Color] = [soft, b, soft, b, strong, b, soft, b, soft]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
    }
}
