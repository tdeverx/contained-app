import SwiftUI

public enum GraphStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case area
    case line
    case bar
    case points
    case multiLine
    case range
    case scatter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .area: return "Area"
        case .line: return "Line"
        case .bar: return "Bar"
        case .points: return "Points"
        case .multiLine: return "Multi-Line"
        case .range: return "Range"
        case .scatter: return "Scatter"
        }
    }

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

public enum WidgetInterpolation: String, CaseIterable, Identifiable, Codable, Sendable {
    case linear, catmullRom, cardinal, monotone, stepStart, stepCenter, stepEnd

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .catmullRom: return "Smooth"
        case .cardinal: return "Cardinal"
        case .monotone: return "Monotone"
        case .stepStart: return "Step Start"
        case .stepCenter: return "Step Center"
        case .stepEnd: return "Step End"
        }
    }
}

/// A compact Canvas renderer for card widgets. Each series is normalized independently so paired
/// metrics with different units still make useful visual comparisons at card scale.
public struct LiveSparkline: View {
    public var samples: [Double]
    public var comparisonSamples: [Double] = []
    public var color: Color = .accentColor
    public var lineWidth: CGFloat = 1.5
    public var style: GraphStyle = .area
    public var areaUsesGradient = true
    public var interpolation: WidgetInterpolation = .catmullRom
    public var pointSize: CGFloat = 18
    public var barWidth: CGFloat = 4

    public init(samples: [Double],
                comparisonSamples: [Double] = [],
                color: Color = .accentColor,
                lineWidth: CGFloat = 1.5,
                style: GraphStyle = .area,
                areaUsesGradient: Bool = true,
                interpolation: WidgetInterpolation = .catmullRom,
                pointSize: CGFloat = 18,
                barWidth: CGFloat = 4) {
        self.samples = samples
        self.comparisonSamples = comparisonSamples
        self.color = color
        self.lineWidth = lineWidth
        self.style = style
        self.areaUsesGradient = areaUsesGradient
        self.interpolation = interpolation
        self.pointSize = pointSize
        self.barWidth = barWidth
    }

    public var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            render(context: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func render(context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard samples.count > 1 else {
            drawBaseline(context: &context, size: size)
            return
        }

        switch style {
        case .area:
            let points = plottedPoints(for: samples, in: size)
            drawArea(points, context: &context, size: size)
            drawLine(points, color: color, context: &context)
        case .line:
            drawLine(plottedPoints(for: samples, in: size), color: color, context: &context)
        case .bar:
            drawBars(values: samples, context: &context, size: size)
        case .points:
            drawPoints(plottedPoints(for: samples, in: size), color: color, context: &context)
        case .multiLine:
            let primary = plottedPoints(for: samples, in: size)
            let secondary = plottedPoints(for: comparisonSamples, in: size)
            drawLine(primary, color: color, context: &context)
            drawLine(secondary, color: color.opacity(0.55), context: &context, dash: [3, 3])
        case .range:
            drawRange(primary: samples, secondary: comparisonSamples, context: &context, size: size)
        case .scatter:
            drawScatter(primary: samples, secondary: comparisonSamples, context: &context, size: size)
        }
    }

    private func drawBaseline(context: inout GraphicsContext, size: CGSize) {
        let inset = drawingInset
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height - inset))
        path.addLine(to: CGPoint(x: size.width, y: size.height - inset))
        context.stroke(path,
                       with: .color(color.opacity(0.35)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private func drawArea(_ points: [CGPoint], context: inout GraphicsContext, size: CGSize) {
        guard points.count > 1 else { return }
        let baseline = size.height - drawingInset
        let path = linePath(points: points, closingToBaseline: baseline)
        if areaUsesGradient {
            context.fill(path,
                         with: .linearGradient(
                            Gradient(colors: [color.opacity(0.25), color.opacity(0.02)]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                         ))
        } else {
            context.fill(path, with: .color(color.opacity(0.22)))
        }
    }

    private func drawLine(_ points: [CGPoint],
                          color: Color,
                          context: inout GraphicsContext,
                          dash: [CGFloat] = []) {
        guard points.count > 1 else { return }
        context.stroke(linePath(points: points),
                       with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth,
                                          lineCap: .round,
                                          lineJoin: .round,
                                          dash: dash))
    }

    private func drawBars(values: [Double], context: inout GraphicsContext, size: CGSize) {
        let points = plottedPoints(for: values, in: size)
        guard !points.isEmpty else { return }
        let baseline = size.height - drawingInset
        let resolvedBarWidth = min(max(barWidth, 1), max(size.width / CGFloat(max(points.count, 1)) * 0.72, 1))
        for point in points {
            let top = min(point.y, baseline)
            let height = max(abs(baseline - point.y), lineWidth)
            let rect = CGRect(x: point.x - resolvedBarWidth / 2,
                              y: top,
                              width: resolvedBarWidth,
                              height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: resolvedBarWidth / 2),
                         with: .color(color.opacity(0.76)))
        }
    }

    private func drawPoints(_ points: [CGPoint], color: Color, context: inout GraphicsContext) {
        let diameter = max(sqrt(pointSize), 2)
        for point in points {
            let rect = CGRect(x: point.x - diameter / 2,
                              y: point.y - diameter / 2,
                              width: diameter,
                              height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawRange(primary: [Double],
                           secondary: [Double],
                           context: inout GraphicsContext,
                           size: CGSize) {
        let first = plottedPoints(for: primary, in: size)
        let second = plottedPoints(for: secondary, in: size)
        let count = min(first.count, second.count)
        guard count > 0 else { return }

        let resolvedBarWidth = min(max(barWidth, 1), max(size.width / CGFloat(count) * 0.72, 1))
        for index in 0..<count {
            let x = first[index].x
            let top = min(first[index].y, second[index].y)
            let height = max(abs(first[index].y - second[index].y), lineWidth)
            let rect = CGRect(x: x - resolvedBarWidth / 2,
                              y: top,
                              width: resolvedBarWidth,
                              height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: resolvedBarWidth / 2),
                         with: .color(color.opacity(0.72)))
        }
    }

    private func drawScatter(primary: [Double],
                             secondary: [Double],
                             context: inout GraphicsContext,
                             size: CGSize) {
        let first = normalized(primary)
        let second = normalized(secondary)
        let count = min(first.count, second.count)
        guard count > 0 else { return }

        let inset = drawingInset
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        let diameter = max(sqrt(pointSize), 2)
        for index in 0..<count {
            let point = CGPoint(x: inset + CGFloat(first[index]) * width,
                                y: inset + CGFloat(1 - second[index]) * height)
            let rect = CGRect(x: point.x - diameter / 2,
                              y: point.y - diameter / 2,
                              width: diameter,
                              height: diameter)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let maxValue = max(values.max() ?? 1, 0.0001)
        return values.map { min(max($0 / maxValue, 0), 1) }
    }

    private func plottedPoints(for values: [Double], in size: CGSize) -> [CGPoint] {
        let normalizedValues = normalized(values)
        guard !normalizedValues.isEmpty else { return [] }
        let inset = drawingInset
        let width = max(size.width, 1)
        let height = max(size.height - inset * 2, 1)
        let denominator = CGFloat(max(normalizedValues.count - 1, 1))

        return normalizedValues.enumerated().map { index, value in
            let x = normalizedValues.count == 1 ? width / 2 : width * CGFloat(index) / denominator
            let y = inset + CGFloat(1 - value) * height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint], closingToBaseline baseline: CGFloat? = nil) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        if let baseline {
            path.move(to: CGPoint(x: first.x, y: baseline))
            path.addLine(to: first)
        } else {
            path.move(to: first)
        }

        appendSegments(points: points, to: &path)

        if let baseline, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: baseline))
            path.closeSubpath()
        }
        return path
    }

    private func appendSegments(points: [CGPoint], to path: inout Path) {
        guard points.count > 1 else { return }
        switch interpolation {
        case .linear, .monotone:
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        case .stepStart:
            appendStepSegments(points: points, to: &path, mode: .start)
        case .stepCenter:
            appendStepSegments(points: points, to: &path, mode: .center)
        case .stepEnd:
            appendStepSegments(points: points, to: &path, mode: .end)
        case .catmullRom:
            appendCatmullRomSegments(points: points, to: &path, tension: 1)
        case .cardinal:
            appendCatmullRomSegments(points: points, to: &path, tension: 0.65)
        }
    }

    private enum StepMode { case start, center, end }

    private func appendStepSegments(points: [CGPoint], to path: inout Path, mode: StepMode) {
        var previous = points[0]
        for point in points.dropFirst() {
            switch mode {
            case .start:
                path.addLine(to: CGPoint(x: previous.x, y: point.y))
                path.addLine(to: point)
            case .center:
                let midpoint = (previous.x + point.x) / 2
                path.addLine(to: CGPoint(x: midpoint, y: previous.y))
                path.addLine(to: CGPoint(x: midpoint, y: point.y))
                path.addLine(to: point)
            case .end:
                path.addLine(to: CGPoint(x: point.x, y: previous.y))
                path.addLine(to: point)
            }
            previous = point
        }
    }

    private func appendCatmullRomSegments(points: [CGPoint], to path: inout Path, tension: CGFloat) {
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let scale = tension / 6
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) * scale,
                                   y: p1.y + (p2.y - p0.y) * scale)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) * scale,
                                   y: p2.y - (p3.y - p1.y) * scale)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
    }

    private var drawingInset: CGFloat {
        max(lineWidth / 2, 1)
    }
}

/// A fixed-size ring buffer for sparkline history.
public struct SampleBuffer: Sendable, Equatable {
    public private(set) var values: [Double] = []
    public let capacity: Int

    public init(capacity: Int = 40) { self.capacity = capacity }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}
