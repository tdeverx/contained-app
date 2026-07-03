import SwiftUI

/// A 360° gradient-direction control: a draggable dial plus a degree readout.
public extension UI.Control {
struct GradientAngle: View {
    @Binding var angle: Double
    public var title: String

    public init(angle: Binding<Double>, title: String) {
        self._angle = angle
        self.title = title
    }

    public var body: some View {
        LabeledContent(title) {
            HStack(spacing: UI.Tokens.Space.m) {
                AngleDial(angle: $angle)
                    .frame(width: UI.Tokens.InlineControl.gradientDial,
                           height: UI.Tokens.InlineControl.gradientDial)
                Slider(value: $angle, in: 0...360, step: 1)
                Text("\(Int(angle))°")
                    .monospacedDigit()
                    .frame(width: UI.Tokens.InlineControl.gradientReadout)
            }
        }
    }
}
}

/// A small dial knob whose pointer reflects the gradient angle; drag to set.
private struct AngleDial: View {
    @Binding var angle: Double

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radians = angle * .pi / 180
            let knob = CGPoint(x: center.x + cos(radians) * (radius - UI.Tokens.InlineControl.gradientKnobInset),
                               y: center.y + sin(radians) * (radius - UI.Tokens.InlineControl.gradientKnobInset))
            ZStack {
                Circle()
                    .strokeBorder(.secondary.opacity(UI.Tokens.InlineControl.gradientStrokeOpacity),
                                  lineWidth: UI.Tokens.Space.hairline)
                Circle()
                    .fill(.tint)
                    .frame(width: UI.Tokens.InlineControl.gradientKnob,
                           height: UI.Tokens.InlineControl.gradientKnob)
                    .position(knob)
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
