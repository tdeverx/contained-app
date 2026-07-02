import SwiftUI
import Charts

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

/// A compact Swift Charts renderer for card widgets. Each series is normalized independently so
/// paired metrics with different units still make useful visual comparisons at card scale.
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
        Group {
            if samples.count > 1 {
                chart
            } else {
                baseline
            }
        }
        .accessibilityHidden(true)
    }

    private var chart: some View {
        Chart {
            switch style {
            case .area:
                ForEach(primaryPoints) { point in
                    AreaMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(areaFillStyle)
                        .interpolationMethod(interpolation.method)
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
            case .line:
                ForEach(primaryPoints) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
            case .bar:
                ForEach(primaryPoints) { point in
                    BarMark(x: .value("Sample", point.index), y: .value("Value", point.value), width: .fixed(barWidth))
                        .clipShape(Capsule())
                        .foregroundStyle(color.opacity(0.76).gradient)
                }
            case .points:
                ForEach(primaryPoints) { point in
                    PointMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .symbolSize(pointSize)
                }
            case .multiLine:
                ForEach(primaryPoints) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value), series: .value("Metric", "Primary"))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
                ForEach(secondaryPoints) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value), series: .value("Metric", "Secondary"))
                        .foregroundStyle(color.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [3, 3]))
                        .interpolationMethod(interpolation.method)
                }
            case .range:
                ForEach(rangePoints) { point in
                    BarMark(x: .value("Sample", point.index),
                            yStart: .value("Low", point.low),
                            yEnd: .value("High", point.high),
                            width: .fixed(barWidth))
                    .clipShape(Capsule())
                    .foregroundStyle(color.opacity(0.72).gradient)
                }
            case .scatter:
                ForEach(scatterPoints) { point in
                    PointMark(x: .value("Primary", point.x), y: .value("Secondary", point.y))
                        .foregroundStyle(color)
                        .symbolSize(pointSize)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: 0...1)
        .chartPlotStyle { plot in
            plot.background(.clear)
        }
    }

    private var baseline: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height - lineWidth))
            path.addLine(to: CGPoint(x: size.width, y: size.height - lineWidth))
            context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: lineWidth)
        }
    }

    private var areaFillStyle: AnyShapeStyle {
        if areaUsesGradient {
            return AnyShapeStyle(
                LinearGradient(colors: [color.opacity(0.25), color.opacity(0.02)],
                               startPoint: .top,
                               endPoint: .bottom)
            )
        }
        return AnyShapeStyle(color.opacity(0.22))
    }

    private var primaryPoints: [ChartPoint] {
        normalized(samples).enumerated().map { ChartPoint(index: $0.offset, value: $0.element) }
    }

    private var secondaryPoints: [ChartPoint] {
        normalized(comparisonSamples).enumerated().map { ChartPoint(index: $0.offset, value: $0.element) }
    }

    private var rangePoints: [ChartRangePoint] {
        let count = min(primaryPoints.count, secondaryPoints.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let first = primaryPoints[index].value
            let second = secondaryPoints[index].value
            return ChartRangePoint(index: index, low: min(first, second), high: max(first, second))
        }
    }

    private var scatterPoints: [ChartScatterPoint] {
        let count = min(primaryPoints.count, secondaryPoints.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            ChartScatterPoint(index: index, x: primaryPoints[index].value, y: secondaryPoints[index].value)
        }
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let maxValue = max(values.max() ?? 1, 0.0001)
        return values.map { min(max($0 / maxValue, 0), 1) }
    }
}

private struct ChartPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}

private struct ChartRangePoint: Identifiable {
    let index: Int
    let low: Double
    let high: Double
    var id: Int { index }
}

private struct ChartScatterPoint: Identifiable {
    let index: Int
    let x: Double
    let y: Double
    var id: Int { index }
}

private extension WidgetInterpolation {
    var method: InterpolationMethod {
        switch self {
        case .linear: return .linear
        case .catmullRom: return .catmullRom
        case .cardinal: return .cardinal
        case .monotone: return .monotone
        case .stepStart: return .stepStart
        case .stepCenter: return .stepCenter
        case .stepEnd: return .stepEnd
        }
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
