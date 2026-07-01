import SwiftUI

/// A plain lightweight line graph of recent samples (CPU/mem/etc.), drawn with a Canvas.
/// The graph scales to the current sample set and keeps its own size/color only.
struct LiveSparkline: View {
    /// Samples in 0...1-ish range (already normalized by the caller).
    var samples: [Double]
    var color: Color = .accentColor
    var lineWidth: CGFloat = 1.5
    var style: GraphStyle = .area

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else {
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height - lineWidth))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth))
                context.stroke(baseline, with: .color(color.opacity(0.35)), lineWidth: lineWidth)
                return
            }

            let maxValue = max(samples.max() ?? 1, 0.0001)
            let stepX = size.width / CGFloat(samples.count - 1)
            let plotted: [CGPoint] = samples.enumerated().map { index, value in
                let x = CGFloat(index) * stepX
                let normalized = min(max(value / maxValue, 0), 1)
                let y = size.height - (CGFloat(normalized) * (size.height - lineWidth)) - lineWidth
                return CGPoint(x: x, y: y)
            }

            var path = Path()
            path.move(to: plotted[0])
            for point in plotted.dropFirst() {
                path.addLine(to: point)
            }

            var fill = path
            if style == .area {
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.25), color.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)))
            }

            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
        .accessibilityHidden(true)
    }
}

/// A fixed-size ring buffer for sparkline history.
struct SampleBuffer: Sendable, Equatable {
    private(set) var values: [Double] = []
    let capacity: Int

    init(capacity: Int = 40) { self.capacity = capacity }

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}
