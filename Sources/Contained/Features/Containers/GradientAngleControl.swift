import SwiftUI

/// A 360° gradient-direction control: a draggable dial plus a degree readout.
struct GradientAngleControl: View {
    @Binding var angle: Double

    var body: some View {
        LabeledContent("Direction") {
            HStack(spacing: Tokens.Space.m) {
                AngleDial(angle: $angle).frame(width: 36, height: 36)
                Slider(value: $angle, in: 0...360, step: 1)
                Text("\(Int(angle))°").monospacedDigit().frame(width: 40)
            }
        }
    }
}

/// A small dial knob whose pointer reflects the gradient angle; drag to set.
struct AngleDial: View {
    @Binding var angle: Double

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radians = angle * .pi / 180
            let knob = CGPoint(x: center.x + cos(radians) * (radius - 4),
                               y: center.y + sin(radians) * (radius - 4))
            ZStack {
                Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                Circle().fill(.tint).frame(width: 7, height: 7).position(knob)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var deg = atan2(dy, dx) * 180 / .pi
                        if deg < 0 { deg += 360 }
                        angle = deg
                    }
            )
        }
    }
}
