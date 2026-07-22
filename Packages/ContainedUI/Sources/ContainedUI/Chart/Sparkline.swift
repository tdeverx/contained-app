import SwiftUI
import Charts

public extension UI.Chart {
enum Style {
    public static func primaryLine(_ mark: LineMark) -> some ChartContent {
        mark.foregroundStyle(Color.accentColor)
            .interpolationMethod(.monotone)
    }

    public static func primaryArea(_ mark: AreaMark) -> some ChartContent {
        mark.foregroundStyle(Color.accentColor.opacity(UI.Tokens.Chart.areaOpacity))
    }

    public static func successLine(_ mark: LineMark) -> some ChartContent {
        mark.foregroundStyle(Color.green)
    }

    public static func warningLine(_ mark: LineMark) -> some ChartContent {
        mark.foregroundStyle(Color.orange)
    }
}

enum GraphStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case area
    case line
    case bar
    case points
    case multiLine
    case range
    case scatter

    public var id: String { rawValue }

    public var requiresSecondaryMetric: Bool {
        switch self {
        case .multiLine, .range, .scatter: return true
        case .area, .line, .bar, .points: return false
        }
    }

    public func resolvedSecondaryMetric<Metric: Equatable>(primary: Metric,
                                                           requested: Metric?,
                                                           options: [Metric]) -> Metric? {
        guard requiresSecondaryMetric else { return nil }
        if let requested, requested != primary, options.contains(requested) {
            return requested
        }
        return options.first { $0 != primary }
    }

    public var usesLineOptions: Bool {
        switch self {
        case .area, .line, .multiLine: return true
        case .bar, .points, .range, .scatter: return false
        }
    }

    public var usesPointOptions: Bool {
        switch self {
        case .points, .scatter: return true
        case .area, .line, .bar, .multiLine, .range: return false
        }
    }

    public var usesBarOptions: Bool {
        switch self {
        case .bar, .range: return true
        case .area, .line, .points, .multiLine, .scatter: return false
        }
    }
}

enum Interpolation: String, CaseIterable, Identifiable, Codable, Sendable {
    case linear, catmullRom, cardinal, monotone, stepStart, stepCenter, stepEnd

    public var id: String { rawValue }

}

enum Scale: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalized
    case fraction

    public var id: String { rawValue }
}

/// A compact asynchronous Canvas renderer for card widgets. Byte/rate metrics can be normalized
/// independently, while pre-normalized fraction metrics can stay anchored to the 0...100% domain.
struct Sparkline: View {
    private static let maximumPlottedSamples = 24

    public var samples: [Double]
    public var comparisonSamples: [Double] = []
    public var color: Color = .accentColor
    public var lineWidth: CGFloat = 1.5
    public var style: UI.Chart.GraphStyle = .area
    public var areaUsesGradient = true
    public var interpolation: UI.Chart.Interpolation = .linear
    public var pointSize: CGFloat = 18
    public var barWidth: CGFloat = 4
    public var scale: UI.Chart.Scale = .normalized
    public var comparisonScale: UI.Chart.Scale = .normalized

    public init(samples: [Double],
                comparisonSamples: [Double] = [],
                color: Color = .accentColor,
                lineWidth: CGFloat = 1.5,
                style: UI.Chart.GraphStyle = .area,
                areaUsesGradient: Bool = true,
                interpolation: UI.Chart.Interpolation = .linear,
                pointSize: CGFloat = 18,
                barWidth: CGFloat = 4,
                scale: UI.Chart.Scale = .normalized,
                comparisonScale: UI.Chart.Scale? = nil) {
        self.samples = samples
        self.comparisonSamples = comparisonSamples
        self.color = color
        self.lineWidth = lineWidth
        self.style = style
        self.areaUsesGradient = areaUsesGradient
        self.interpolation = interpolation
        self.pointSize = pointSize
        self.barWidth = barWidth
        self.scale = scale
        self.comparisonScale = comparisonScale ?? scale
    }

    public var body: some View {
        let plotted = plottedSamples(samples)
        Group {
            if plotted.count > 1 {
                chart
            } else {
                baseline
            }
        }
        .accessibilityHidden(true)
    }

    private var chart: some View {
        let primary = SparklineGeometry.series(samples, scale: scale,
                                               capacity: Self.maximumPlottedSamples)
        let secondary = SparklineGeometry.series(comparisonSamples, scale: comparisonScale,
                                                 capacity: Self.maximumPlottedSamples)
        return Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
            let primaryPoints = SparklineGeometry.points(primary, in: size,
                                                         capacity: Self.maximumPlottedSamples)
            let secondaryPoints = SparklineGeometry.points(secondary, in: size,
                                                           capacity: Self.maximumPlottedSamples)
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            switch style {
            case .area:
                var area = SparklineGeometry.path(primaryPoints, interpolation: interpolation)
                if let first = primaryPoints.first, let last = primaryPoints.last {
                    area.addLine(to: CGPoint(x: last.x, y: size.height))
                    area.addLine(to: CGPoint(x: first.x, y: size.height))
                    area.closeSubpath()
                    if areaUsesGradient {
                        context.fill(area, with: .linearGradient(
                            Gradient(colors: [color.opacity(0.25), color.opacity(0.02)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        ))
                    } else {
                        context.fill(area, with: .color(color.opacity(0.22)))
                    }
                }
                context.stroke(SparklineGeometry.path(primaryPoints, interpolation: interpolation),
                               with: .color(color), style: stroke)
            case .line:
                context.stroke(SparklineGeometry.path(primaryPoints, interpolation: interpolation),
                               with: .color(color), style: stroke)
            case .bar:
                SparklineGeometry.drawBars(primaryPoints, bottom: size.height, width: barWidth,
                                           color: color.opacity(0.76), in: &context)
            case .points:
                SparklineGeometry.drawPoints(primaryPoints, area: pointSize, color: color, in: &context)
            case .multiLine:
                context.stroke(SparklineGeometry.path(primaryPoints, interpolation: interpolation),
                               with: .color(color), style: stroke)
                context.stroke(SparklineGeometry.path(secondaryPoints, interpolation: interpolation),
                               with: .color(color.opacity(0.55)),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                                  lineJoin: .round, dash: [3, 3]))
            case .range:
                SparklineGeometry.drawRanges(primaryPoints, secondaryPoints,
                                             width: barWidth, color: color.opacity(0.72), in: &context)
            case .scatter:
                SparklineGeometry.drawPoints(primaryPoints, area: pointSize, color: color, in: &context)
                SparklineGeometry.drawPoints(secondaryPoints, area: pointSize * 0.7,
                                             color: color.opacity(0.55), in: &context)
            }
        }
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
    }

    private var baseline: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height - lineWidth))
            path.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth))
            context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: lineWidth)
        }
    }

    private func plottedSamples(_ values: [Double]) -> [Double] {
        // Keep the chart empty until there is data. Padding belongs to a renderer that needs a
        // fixed sample window; doing it here made a brand-new card build a 24-mark chart instead
        // of the inexpensive baseline placeholder.
        values.suffix(Self.maximumPlottedSamples).map(SparklineSeriesScaling.sanitizedSample)
    }
}
}

enum SparklineSeriesScaling {
    private static let minimumCeiling = 0.0001

    static func paddedWindow(_ values: [Double], capacity: Int) -> [Double] {
        let latest = values.suffix(capacity).map(sanitizedSample)
        guard latest.count < capacity else { return latest }
        return Array(repeating: 0, count: capacity - latest.count) + latest
    }

    static func normalized(_ values: [Double]) -> [Double] {
        let ceiling = displayCeiling(for: values)
        return values.map { min(max(sanitizedSample($0) / ceiling, 0), 1) }
    }

    static func fractions(_ values: [Double]) -> [Double] {
        values.map { min(max(sanitizedSample($0), 0), 1) }
    }

    static func scaled(_ values: [Double], mode: UI.Chart.Scale) -> [Double] {
        switch mode {
        case .normalized: return normalized(values)
        case .fraction: return fractions(values)
        }
    }

    static func displayCeiling(for values: [Double]) -> Double {
        let positives = values.map(sanitizedSample).filter { $0 > 0 }.sorted()
        guard let maximum = positives.last else { return 1 }
        guard positives.count >= 4 else { return max(maximum, minimumCeiling) }

        // One noisy stats sample should render as a clipped spike, not rescale the whole visible window.
        let percentileIndex = Int(Double(positives.count - 1) * 0.9)
        let robustHigh = positives[percentileIndex]
        return max(robustHigh * 1.35, minimumCeiling)
    }

    static func sanitizedSample(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }
}

struct SparklineSeriesPoint: Equatable, Sendable {
    let index: Int
    let value: Double
}

enum SparklineGeometry {
    static func series(_ values: [Double], scale: UI.Chart.Scale,
                       capacity: Int) -> [SparklineSeriesPoint] {
        let latest = values.suffix(capacity).map(SparklineSeriesScaling.sanitizedSample)
        let scaled = SparklineSeriesScaling.scaled(latest, mode: scale)
        let start = capacity - scaled.count
        return scaled.enumerated().map { SparklineSeriesPoint(index: start + $0.offset, value: $0.element) }
    }

    static func points(_ series: [SparklineSeriesPoint], in size: CGSize,
                       capacity: Int) -> [CGPoint] {
        let divisor = CGFloat(max(capacity - 1, 1))
        return series.map { point in
            CGPoint(x: CGFloat(point.index) / divisor * size.width,
                    y: (1 - CGFloat(min(max(point.value, 0), 1))) * size.height)
        }
    }

    static func path(_ points: [CGPoint], interpolation: UI.Chart.Interpolation) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        switch interpolation {
        case .linear:
            for point in points.dropFirst() { path.addLine(to: point) }
        case .stepStart:
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                path.addLine(to: CGPoint(x: current.x, y: previous.y))
                path.addLine(to: current)
            }
        case .stepCenter:
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let middle = (previous.x + current.x) / 2
                path.addLine(to: CGPoint(x: middle, y: previous.y))
                path.addLine(to: CGPoint(x: middle, y: current.y))
                path.addLine(to: current)
            }
        case .stepEnd:
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                path.addLine(to: CGPoint(x: previous.x, y: current.y))
                path.addLine(to: current)
            }
        case .catmullRom, .cardinal, .monotone:
            let tension: CGFloat = interpolation == .cardinal ? 0.34 : 0.22
            for index in 1..<points.count {
                let p0 = points[max(0, index - 2)]
                let p1 = points[index - 1]
                let p2 = points[index]
                let p3 = points[min(points.count - 1, index + 1)]
                var c1 = CGPoint(x: p1.x + (p2.x - p0.x) * tension,
                                 y: p1.y + (p2.y - p0.y) * tension)
                var c2 = CGPoint(x: p2.x - (p3.x - p1.x) * tension,
                                 y: p2.y - (p3.y - p1.y) * tension)
                if interpolation == .monotone {
                    let low = min(p1.y, p2.y)
                    let high = max(p1.y, p2.y)
                    c1.y = min(max(c1.y, low), high)
                    c2.y = min(max(c2.y, low), high)
                }
                path.addCurve(to: p2, control1: c1, control2: c2)
            }
        }
        return path
    }

    static func drawBars(_ points: [CGPoint], bottom: CGFloat, width: CGFloat,
                         color: Color, in context: inout GraphicsContext) {
        for point in points {
            let rect = CGRect(x: point.x - width / 2, y: point.y,
                              width: width, height: max(bottom - point.y, 0.5))
            context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
        }
    }

    static func drawPoints(_ points: [CGPoint], area: CGFloat, color: Color,
                           in context: inout GraphicsContext) {
        let diameter = max(sqrt(max(area, 1)), 1)
        for point in points {
            let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                              width: diameter, height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    static func drawRanges(_ primary: [CGPoint], _ secondary: [CGPoint], width: CGFloat,
                           color: Color, in context: inout GraphicsContext) {
        let count = min(primary.count, secondary.count)
        guard count > 0 else { return }
        let first = primary.suffix(count)
        let second = secondary.suffix(count)
        for (lhs, rhs) in zip(first, second) {
            let top = min(lhs.y, rhs.y)
            let rect = CGRect(x: lhs.x - width / 2, y: top,
                              width: width, height: max(abs(lhs.y - rhs.y), 0.5))
            context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
        }
    }
}

/// A fixed-size ring buffer for sparkline history.
public extension UI.Chart {
struct SampleBuffer: Sendable, Equatable {
    public private(set) var values: [Double] = []
    public let capacity: Int

    public init(capacity: Int = 40) { self.capacity = capacity }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}
}

#Preview("Sparkline Styles") {
    VStack(spacing: UI.Tokens.Space.l) {
        UI.Chart.Sparkline(samples: [0.1, 0.22, 0.18, 0.44, 0.36, 0.72],
                           color: .accentColor,
                           style: .area,
                           scale: .fraction)
        UI.Chart.Sparkline(samples: [4, 8, 6, 12, 10, 15],
                           color: .teal,
                           style: .line)
        UI.Chart.Sparkline(samples: [0.2, 0.5, 0.35, 0.78, 0.58],
                           comparisonSamples: [0.12, 0.25, 0.42, 0.4, 0.62],
                           color: .orange,
                           style: .multiLine,
                           scale: .fraction)
    }
    .frame(width: 360, height: 180)
    .padding(UI.Tokens.Space.xl)
}
