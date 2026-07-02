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

}

public enum SparklineScale: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalized
    case fraction

    public var id: String { rawValue }
}

/// A compact Swift Charts renderer for card widgets. Byte/rate metrics can be normalized
/// independently, while pre-normalized fraction metrics can stay anchored to the 0...100% domain.
public struct LiveSparkline: View {
    private static let maximumPlottedSamples = 24

    public var samples: [Double]
    public var comparisonSamples: [Double] = []
    public var color: Color = .accentColor
    public var lineWidth: CGFloat = 1.5
    public var style: GraphStyle = .area
    public var areaUsesGradient = true
    public var interpolation: WidgetInterpolation = .linear
    public var pointSize: CGFloat = 18
    public var barWidth: CGFloat = 4
    public var scale: SparklineScale = .normalized
    public var comparisonScale: SparklineScale = .normalized

    public init(samples: [Double],
                comparisonSamples: [Double] = [],
                color: Color = .accentColor,
                lineWidth: CGFloat = 1.5,
                style: GraphStyle = .area,
                areaUsesGradient: Bool = true,
                interpolation: WidgetInterpolation = .linear,
                pointSize: CGFloat = 18,
                barWidth: CGFloat = 4,
                scale: SparklineScale = .normalized,
                comparisonScale: SparklineScale? = nil) {
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
        let primary = primaryPoints
        let secondary = secondaryPoints
        let ranges = rangePoints(primary: primary, secondary: secondary)

        return Chart {
            switch style {
            case .area:
                ForEach(primary) { point in
                    AreaMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(areaFillStyle)
                        .interpolationMethod(interpolation.method)
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
            case .line:
                ForEach(primary) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
            case .bar:
                ForEach(primary) { point in
                    BarMark(x: .value("Sample", point.index), y: .value("Value", point.value), width: .fixed(barWidth))
                        .clipShape(Capsule())
                        .foregroundStyle(color.opacity(0.76).gradient)
                }
            case .points:
                ForEach(primary) { point in
                    PointMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .symbolSize(pointSize)
                }
            case .multiLine:
                ForEach(primary) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value), series: .value("Metric", "Primary"))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolation.method)
                }
                ForEach(secondary) { point in
                    LineMark(x: .value("Sample", point.index), y: .value("Value", point.value), series: .value("Metric", "Secondary"))
                        .foregroundStyle(color.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [3, 3]))
                        .interpolationMethod(interpolation.method)
                }
            case .range:
                ForEach(ranges) { point in
                    BarMark(x: .value("Sample", point.index),
                            yStart: .value("Low", point.low),
                            yEnd: .value("High", point.high),
                            width: .fixed(barWidth))
                    .clipShape(Capsule())
                    .foregroundStyle(color.opacity(0.72).gradient)
                }
            case .scatter:
                ForEach(primary) { point in
                    PointMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color)
                        .symbolSize(pointSize)
                }
                ForEach(secondary) { point in
                    PointMark(x: .value("Sample", point.index), y: .value("Value", point.value))
                        .foregroundStyle(color.opacity(0.55))
                        .symbolSize(pointSize * 0.7)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...(Self.maximumPlottedSamples - 1))
        .chartYScale(domain: 0...1)
        .chartPlotStyle { plot in
            plot.background(.clear)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
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
        chartPoints(for: samples, scale: scale)
    }

    private var secondaryPoints: [ChartPoint] {
        chartPoints(for: comparisonSamples, scale: comparisonScale)
    }

    private func rangePoints(primary: [ChartPoint], secondary: [ChartPoint]) -> [ChartRangePoint] {
        let count = min(primary.count, secondary.count)
        guard count > 0 else { return [] }
        let primaryTail = Array(primary.suffix(count))
        let secondaryTail = Array(secondary.suffix(count))
        return primaryTail.indices.map { index in
            let first = primaryTail[index]
            let second = secondaryTail[index]
            return ChartRangePoint(index: first.index,
                                   low: min(first.value, second.value),
                                   high: max(first.value, second.value))
        }
    }

    private func chartPoints(for values: [Double], scale: SparklineScale) -> [ChartPoint] {
        let plotted = plottedSamples(values)
        let startIndex = Self.maximumPlottedSamples - plotted.count
        let scaled = SparklineSeriesScaling.scaled(plotted, mode: scale)
        return scaled.enumerated().map { offset, value in
            ChartPoint(index: startIndex + offset, value: value)
        }
    }

    private func plottedSamples(_ values: [Double]) -> [Double] {
        SparklineSeriesScaling.paddedWindow(values, capacity: Self.maximumPlottedSamples)
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

    static func scaled(_ values: [Double], mode: SparklineScale) -> [Double] {
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

    private static func sanitizedSample(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
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

private extension WidgetInterpolation {
    var method: InterpolationMethod {
        switch self {
        case .linear: return .linear
        case .catmullRom: return .monotone
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
