import SwiftUI
import ContainedUI
import SwiftData
import Charts
import ContainedCore

enum HistoryViewport: Int, CaseIterable, Identifiable {
    case oneHour = 1
    case sixHours = 6
    case twelveHours = 12
    case twentyFourHours = 24

    var id: Int { rawValue }
    var title: String { "\(rawValue)h" }
    var duration: TimeInterval { TimeInterval(rawValue) * 3_600 }
    var axisStrideMinutes: Int {
        switch self {
        case .oneHour: return 15
        case .sixHours: return 60
        case .twelveHours: return 120
        case .twentyFourHours: return 240
        }
    }
}

/// Persistent CPU / memory / network / disk history for one container — the long-term counterpart
/// to the live metric cards on Overview.
struct ContainerStatisticsTab: View {
    @Environment(AppModel.self) private var app
    let snapshot: Core.Container.Snapshot
    let viewport: HistoryViewport
    let interpolation: UI.Chart.Interpolation
    let tint: Color

    var body: some View {
        ContainerTabScaffold {
            LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                ContainerStatisticsWindow(snapshot: snapshot,
                                       retentionDays: app.settings.historyRetentionDays,
                                       normalization: app.statsNormalizationContext,
                                       viewport: viewport,
                                       interpolation: interpolation,
                                       tint: tint)
            }
        }
    }
}

/// The charts + event list for one container. A model actor fetches only this window and returns
/// value-semantic rows rather than exposing SwiftData models to the view.
private struct ContainerStatisticsWindow: View {
    @Environment(AppModel.self) private var app
    private let snapshot: Core.Container.Snapshot
    private let retentionDays: Int
    private let normalization: Core.Metrics.NormalizationContext
    private let viewport: HistoryViewport
    private let interpolation: UI.Chart.Interpolation
    private let tint: Color
    @State private var history: [MetricSampleSnapshot] = []
    @State private var chartPoints: [HistoryChartPoint] = []

    init(snapshot: Core.Container.Snapshot,
         retentionDays: Int,
         normalization: Core.Metrics.NormalizationContext,
         viewport: HistoryViewport,
         interpolation: UI.Chart.Interpolation,
         tint: Color) {
        self.snapshot = snapshot
        self.retentionDays = retentionDays
        self.normalization = normalization
        self.viewport = viewport
        self.interpolation = interpolation
        self.tint = tint
    }

    var body: some View {
        let initialPosition = chartPoints.last.map {
            HistoryTimeline.initialScrollPosition(latest: $0.timestamp, viewport: viewport)
        } ?? Date().addingTimeInterval(-viewport.duration)

        LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.l) {
            if chartPoints.isEmpty {
                UI.State.Empty(AppText.string("history.empty", defaultValue: "No history yet"),
                                 systemImage: "chart.xyaxis.line",
                                 description: AppText.string("history.empty.description", defaultValue: "Samples accumulate while Contained is running."),
                                 minHeight: UI.Chart.Size.emptyHeight)
            } else {
                LazyVStack(alignment: .leading, spacing: UI.Layout.Spacing.s) {
                    chartCard("CPU", unit: percentUnit, initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.primaryLine(
                                LineMark(x: .value("Time", point.timestamp),
                                         y: .value("CPU", point.cpuPercent),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .percentHistoryScale(HistoryPercentScale(values: visiblePoints.map(\.cpuPercent)))
                    }
                    chartCard("Memory", unit: percentUnit, initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.primaryArea(
                                AreaMark(x: .value("Time", point.timestamp),
                                         y: .value("Memory", point.memoryPercent),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .percentHistoryScale(HistoryPercentScale(values: visiblePoints.map(\.memoryPercent)))
                    }
                    chartCard("Network In", unit: "KB/s", initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.themedLine(
                                LineMark(x: .value("Time", point.timestamp),
                                         y: .value("Rx", point.netRxKBPerSec),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .rateHistoryScale(HistoryValueScale(values: visiblePoints.map(\.netRxKBPerSec)))
                    }
                    chartCard("Network Out", unit: "KB/s", initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.themedLine(
                                LineMark(x: .value("Time", point.timestamp),
                                         y: .value("Tx", point.netTxKBPerSec),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .rateHistoryScale(HistoryValueScale(values: visiblePoints.map(\.netTxKBPerSec)))
                    }
                    chartCard("Disk Read", unit: "KB/s", initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.primaryLine(
                                LineMark(x: .value("Time", point.timestamp),
                                         y: .value("Read", point.diskReadKBPerSec),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .rateHistoryScale(HistoryValueScale(values: visiblePoints.map(\.diskReadKBPerSec)))
                    }
                    chartCard("Disk Write", unit: "KB/s", initialPosition: initialPosition) { renderedPoints, visiblePoints in
                        Chart(renderedPoints) { point in
                            UI.Chart.Style.themedLine(
                                LineMark(x: .value("Time", point.timestamp),
                                         y: .value("Write", point.diskWriteKBPerSec),
                                         series: .value("Segment", point.segment)),
                                color: tint,
                                interpolation: interpolation
                            )
                        }
                        .chartForegroundStyleScale(range: [tint])
                        .rateHistoryScale(HistoryValueScale(values: visiblePoints.map(\.diskWriteKBPerSec)))
                    }
                }
            }

        }
        .task(id: HistoryLoadKey(scopedContainerID: snapshot.scopedID, retentionDays: retentionDays)) {
            let cutoff = Date().addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
            let loaded = await app.historyStore.containerMetrics(scopedContainerID: snapshot.scopedID, since: cutoff)
            guard !Task.isCancelled else { return }
            history = loaded
            rebuildChartPoints()
        }
        .onChange(of: normalization) { _, _ in
            rebuildChartPoints()
        }
    }

    private func rebuildChartPoints() {
        chartPoints = HistoryChartPoint.points(
            from: history,
            snapshot: snapshot,
            normalization: normalization,
            maximumPoints: max(history.count, 1)
        )
    }

    private func chartCard<C: View>(_ title: String,
                                    unit: String,
                                    initialPosition: Date,
                                    @ViewBuilder chart: @escaping ([HistoryChartPoint], [HistoryChartPoint]) -> C) -> some View {
        HistoryScrollableChartCard(title: title,
                                   unit: unit,
                                   points: chartPoints,
                                   viewport: viewport,
                                   initialPosition: initialPosition,
                                   chart: chart)
    }

    private var percentUnit: String {
        switch normalization.mode {
        case .container: return "% of container"
        case .machine: return "% of machine"
        }
    }
}

/// Owns scroll and settled-window state at the individual graph boundary. A gesture invalidates
/// only this chart, and its Y scale remains stable until the hourly snap has come to rest.
private struct HistoryScrollableChartCard<ChartContent: View>: View {
    let title: String
    let unit: String
    let points: [HistoryChartPoint]
    let viewport: HistoryViewport
    @ViewBuilder let chart: ([HistoryChartPoint], [HistoryChartPoint]) -> ChartContent
    @State private var scrollPosition: Date
    @State private var settledPosition: Date
    @State private var settledPoints: [HistoryChartPoint]
    @State private var renderedPoints: [HistoryChartPoint]
    @State private var renderedRange: ClosedRange<Date>

    init(title: String,
         unit: String,
         points: [HistoryChartPoint],
         viewport: HistoryViewport,
         initialPosition: Date,
         @ViewBuilder chart: @escaping ([HistoryChartPoint], [HistoryChartPoint]) -> ChartContent) {
        self.title = title
        self.unit = unit
        self.points = points
        self.viewport = viewport
        self.chart = chart
        _scrollPosition = State(initialValue: initialPosition)
        _settledPosition = State(initialValue: initialPosition)
        let visible = HistoryTimeline.visiblePoints(in: points,
                                                    from: initialPosition,
                                                    viewport: viewport)
        let buffer = HistoryTimeline.bufferedRange(around: initialPosition, viewport: viewport)
        _settledPoints = State(initialValue: visible)
        _renderedPoints = State(initialValue: HistoryTimeline.points(in: points, range: buffer))
        _renderedRange = State(initialValue: buffer)
    }

    var body: some View {
        UI.Surface.Section(header: title,
                           elevated: false,
                           material: .card,
                           padding: UI.Layout.Spacing.s) {
            Text(unit).designSecondaryCaption()
        } content: {
            chart(renderedPoints, settledPoints)
                .frame(height: UI.Chart.Size.height)
                .chartScrollableAxes(.horizontal)
                .chartXScale(domain: xDomain)
                .chartXVisibleDomain(length: viewport.duration)
                .chartScrollPosition(x: $scrollPosition)
                .chartScrollTargetBehavior(
                    .valueAligned(matching: DateComponents(minute: 0), limitBehavior: .always)
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: viewport.axisStrideMinutes)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                if Calendar.current.component(.hour, from: date) == 0 {
                                    Text(date, format: .dateTime.day().month(.abbreviated))
                                } else {
                                    Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                                }
                            }
                        }
                    }
                }
                .transaction { transaction in transaction.animation = nil }
        }
        .onChange(of: viewport) { oldViewport, newViewport in
            let shifted = scrollPosition.addingTimeInterval(oldViewport.duration - newViewport.duration)
            scrollPosition = shifted
            settledPosition = shifted
            settledPoints = HistoryTimeline.visiblePoints(in: points, from: shifted, viewport: newViewport)
            updateRenderedPoints(around: shifted, viewport: newViewport)
        }
        .onChange(of: points) { _, newPoints in
            settledPoints = HistoryTimeline.visiblePoints(in: newPoints,
                                                          from: settledPosition,
                                                          viewport: viewport)
            updateRenderedPoints(around: scrollPosition, viewport: viewport, points: newPoints)
        }
        .onChange(of: scrollPosition) { _, newPosition in
            let margin = viewport.duration / 4
            let visibleEnd = newPosition.addingTimeInterval(viewport.duration)
            if newPosition < renderedRange.lowerBound.addingTimeInterval(margin)
                || visibleEnd > renderedRange.upperBound.addingTimeInterval(-margin) {
                updateRenderedPoints(around: newPosition, viewport: viewport)
            }
        }
        .task(id: HistoryScaleRequest(position: scrollPosition, viewport: viewport)) {
            do {
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            settledPosition = scrollPosition
            settledPoints = HistoryTimeline.visiblePoints(in: points,
                                                          from: scrollPosition,
                                                          viewport: viewport)
        }
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = points.first?.timestamp, let last = points.last?.timestamp else {
            let now = Date()
            return now...now.addingTimeInterval(viewport.duration)
        }
        return first...(last > first ? last : first.addingTimeInterval(viewport.duration))
    }

    private func updateRenderedPoints(around position: Date,
                                      viewport: HistoryViewport,
                                      points sourcePoints: [HistoryChartPoint]? = nil) {
        let range = HistoryTimeline.bufferedRange(around: position, viewport: viewport)
        renderedRange = range
        renderedPoints = HistoryTimeline.points(in: sourcePoints ?? points, range: range)
    }
}

private struct HistoryLoadKey: Hashable {
    let scopedContainerID: String
    let retentionDays: Int
}

private struct HistoryScaleRequest: Hashable {
    let position: Date
    let viewport: HistoryViewport
}

enum HistoryTimeline {
    static func initialScrollPosition(latest: Date,
                                      viewport: HistoryViewport) -> Date {
        latest.addingTimeInterval(-viewport.duration)
    }

    static func bufferedRange(around position: Date,
                              viewport: HistoryViewport) -> ClosedRange<Date> {
        let lower = position.addingTimeInterval(-viewport.duration)
        let upper = position.addingTimeInterval(viewport.duration * 2)
        return lower...upper
    }

    static func visiblePoints(in points: [HistoryChartPoint],
                              from position: Date,
                              viewport: HistoryViewport) -> [HistoryChartPoint] {
        Self.points(in: points,
                    range: position...position.addingTimeInterval(viewport.duration))
    }

    static func points(in points: [HistoryChartPoint],
                       range: ClosedRange<Date>) -> [HistoryChartPoint] {
        guard !points.isEmpty else { return [] }
        let lower = lowerBound(in: points, for: range.lowerBound)
        let upper = lowerBound(in: points, for: range.upperBound, includingEqual: true)
        guard lower < upper else { return [] }
        return Array(points[lower..<upper])
    }

    private static func lowerBound(in points: [HistoryChartPoint],
                                   for timestamp: Date,
                                   includingEqual: Bool = false) -> Int {
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let precedesBoundary = includingEqual
                ? points[middle].timestamp <= timestamp
                : points[middle].timestamp < timestamp
            if precedesBoundary {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}

/// A data-driven percentage axis that keeps small workloads legible without inventing precision.
/// The upper bound advances through familiar 1/2/5 steps and never exceeds the semantic 100% cap.
struct HistoryPercentScale: Equatable {
    let upperBound: Double

    init(values: [Double]) {
        let peak = values.lazy.filter(\.isFinite).filter { $0 > 0 }.max() ?? 0
        upperBound = Self.roundedCeiling(for: peak)
    }

    var domain: ClosedRange<Double> { 0...upperBound }
    var axisValues: [Double] {
        (0...4).map { upperBound * Double($0) / 4 }
    }

    private static func roundedCeiling(for peak: Double) -> Double {
        guard peak > 0 else { return 1 }

        let magnitude = pow(10, floor(log10(peak)))
        let normalized = peak / magnitude
        let rounded: Double
        if normalized <= 1 {
            rounded = 1
        } else if normalized <= 2 {
            rounded = 2
        } else if normalized <= 5 {
            rounded = 5
        } else {
            rounded = 10
        }
        return min(rounded * magnitude, 100)
    }
}

/// Throughput charts use the same stable 1/2/5 progression without a percentage ceiling.
struct HistoryValueScale: Equatable {
    let upperBound: Double

    init(values: [Double]) {
        let peak = values.lazy.filter(\.isFinite).filter { $0 > 0 }.max() ?? 0
        upperBound = Self.roundedCeiling(for: peak)
    }

    var domain: ClosedRange<Double> { 0...upperBound }
    var axisValues: [Double] {
        (0...4).map { upperBound * Double($0) / 4 }
    }

    private static func roundedCeiling(for peak: Double) -> Double {
        guard peak > 0 else { return 1 }
        let magnitude = pow(10, floor(log10(peak)))
        let normalized = peak / magnitude
        let rounded = normalized <= 1 ? 1.0 : (normalized <= 2 ? 2.0 : (normalized <= 5 ? 5.0 : 10.0))
        return rounded * magnitude
    }
}

struct HistoryChartPoint: Identifiable, Equatable {
    static let maximumRenderedPoints = 600
    /// A missing run of samples means Contained was inactive, asleep, or not running. Segmenting
    /// prevents Charts from drawing a misleading uninterrupted line across that interval.
    static let maximumContinuousGap: TimeInterval = 15 * 60
    let id: Int
    let timestamp: Date
    let segment: Int
    let cpuPercent: Double
    let memoryPercent: Double
    let netRxKBPerSec: Double
    let netTxKBPerSec: Double
    let diskReadKBPerSec: Double
    let diskWriteKBPerSec: Double

    static func points(from samples: [MetricSampleSnapshot],
                       snapshot: Core.Container.Snapshot,
                       normalization: Core.Metrics.NormalizationContext,
                       maximumPoints: Int = maximumRenderedPoints) -> [HistoryChartPoint] {
        guard !samples.isEmpty else { return [] }

        let memoryFallbackBytes = samples.reduce(UInt64(0)) { current, sample in
            max(current, bytes(from: sample.memoryBytes))
        }
        let cpuLimit = normalization.cpuLimit(for: snapshot)
        let memoryLimit = normalization.memoryLimitBytes(for: snapshot, fallback: memoryFallbackBytes)

        return segmentedDownsample(samples, maximumPoints: maximumPoints).enumerated().map { index, rendered in
            let sample = rendered.sample
            let cpu = sanitized(sample.cpuFraction) / cpuLimit
            let memory = memoryLimit > 0 ? sanitized(sample.memoryBytes) / Double(memoryLimit) : 0
            return HistoryChartPoint(id: index,
                                     timestamp: sample.timestamp,
                                     segment: rendered.segment,
                                     cpuPercent: percent(cpu),
                                     memoryPercent: percent(memory),
                                     netRxKBPerSec: sanitized(sample.netRxBytesPerSec) / 1024,
                                     netTxKBPerSec: sanitized(sample.netTxBytesPerSec) / 1024,
                                     diskReadKBPerSec: sanitized(sample.diskReadBytesPerSec) / 1024,
                                     diskWriteKBPerSec: sanitized(sample.diskWriteBytesPerSec) / 1024)
        }
    }

    /// Charts become needlessly expensive when a week of one-minute samples produces ten thousand
    /// marks. Reduce adjacent samples to a bounded, time-ordered low/high envelope rather than
    /// averaging away short peaks; full-resolution history remains in SwiftData.
    static func downsample(_ samples: [MetricSampleSnapshot],
                           maximumPoints: Int = maximumRenderedPoints) -> [MetricSampleSnapshot] {
        guard maximumPoints > 0, samples.count > maximumPoints else { return samples }
        let maxima = metricMaxima(in: samples)
        guard maximumPoints > 1 else {
            return [samples.max(by: { activityMagnitude($0, maxima: maxima) < activityMagnitude($1, maxima: maxima) })!]
        }

        let bucketCount = max(maximumPoints / 2, 1)
        let bucketSize = Double(samples.count) / Double(bucketCount)
        var selected: [MetricSampleSnapshot] = []
        selected.reserveCapacity(maximumPoints)

        for bucket in 0..<bucketCount {
            let lower = Int((Double(bucket) * bucketSize).rounded(.down))
            let upper = min(Int((Double(bucket + 1) * bucketSize).rounded(.down)), samples.count)
            guard lower < upper else { continue }
            let window = samples[lower..<upper]
            let low = window.min(by: { activityMagnitude($0, maxima: maxima) < activityMagnitude($1, maxima: maxima) })!
            let high = window.max(by: { activityMagnitude($0, maxima: maxima) < activityMagnitude($1, maxima: maxima) })!
            let second = high.timestamp == low.timestamp && window.count > 1 ? window.last! : high
            if low.timestamp <= second.timestamp {
                selected.append(low)
                selected.append(second)
            } else {
                selected.append(second)
                selected.append(low)
            }
        }
        return Array(selected.prefix(maximumPoints))
    }

    private struct MetricMaxima {
        let cpu: Double
        let memory: Double
        let netRx: Double
        let netTx: Double
        let diskRead: Double
        let diskWrite: Double
    }

    private static func metricMaxima(in samples: [MetricSampleSnapshot]) -> MetricMaxima {
        MetricMaxima(cpu: max(samples.map(\.cpuFraction).max() ?? 0, 1),
                     memory: max(samples.map(\.memoryBytes).max() ?? 0, 1),
                     netRx: max(samples.map(\.netRxBytesPerSec).max() ?? 0, 1),
                     netTx: max(samples.map(\.netTxBytesPerSec).max() ?? 0, 1),
                     diskRead: max(samples.map(\.diskReadBytesPerSec).max() ?? 0, 1),
                     diskWrite: max(samples.map(\.diskWriteBytesPerSec).max() ?? 0, 1))
    }

    private static func activityMagnitude(_ sample: MetricSampleSnapshot, maxima: MetricMaxima) -> Double {
        [sample.cpuFraction / maxima.cpu,
         sample.memoryBytes / maxima.memory,
         sample.netRxBytesPerSec / maxima.netRx,
         sample.netTxBytesPerSec / maxima.netTx,
         sample.diskReadBytesPerSec / maxima.diskRead,
         sample.diskWriteBytesPerSec / maxima.diskWrite].max() ?? 0
    }

    private struct SegmentedSample {
        let sample: MetricSampleSnapshot
        let segment: Int
    }

    /// Detect real collection gaps before reducing the series. Segmenting after downsampling made
    /// a continuous seven-day window appear empty because its rendered points land about 17 minutes
    /// apart—just beyond `maximumContinuousGap`—and every LineMark became a one-point series.
    private static func segmentedDownsample(
        _ samples: [MetricSampleSnapshot],
        maximumPoints: Int = maximumRenderedPoints
    ) -> [SegmentedSample] {
        guard maximumPoints > 0, !samples.isEmpty else { return [] }

        var segments: [[MetricSampleSnapshot]] = [[]]
        for sample in samples {
            if let previous = segments[segments.count - 1].last,
               sample.timestamp.timeIntervalSince(previous.timestamp) > maximumContinuousGap {
                segments.append([])
            }
            segments[segments.count - 1].append(sample)
        }

        guard samples.count > maximumPoints else {
            return segments.enumerated().flatMap { segment, samples in
                samples.map { SegmentedSample(sample: $0, segment: segment) }
            }
        }

        // A pathological history can contain more real gaps than the rendering budget. Preserve an
        // evenly distributed overview in that case; a one-point segment is the honest representation.
        if segments.count >= maximumPoints {
            let stride = Double(segments.count) / Double(maximumPoints)
            return (0..<maximumPoints).map { index in
                let segment = min(Int((Double(index) * stride).rounded(.down)), segments.count - 1)
                return SegmentedSample(sample: segments[segment][segments[segment].count / 2],
                                       segment: segment)
            }
        }

        var allocations = [Int](repeating: 1, count: segments.count)
        var remaining = maximumPoints - segments.count
        while remaining > 0 {
            guard let next = segments.indices
                .filter({ allocations[$0] < segments[$0].count })
                .max(by: {
                    Double(segments[$0].count) / Double(allocations[$0])
                        < Double(segments[$1].count) / Double(allocations[$1])
                })
            else { break }
            allocations[next] += 1
            remaining -= 1
        }

        return segments.enumerated().flatMap { segment, samples in
            downsample(samples, maximumPoints: allocations[segment]).map {
                SegmentedSample(sample: $0, segment: segment)
            }
        }
    }

    private static func percent(_ fraction: Double) -> Double {
        min(max(sanitized(fraction), 0), 1) * 100
    }

    private static func sanitized(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return value
    }

    private static func bytes(from value: Double) -> UInt64 {
        UInt64(min(sanitized(value), Double(UInt64.max)))
    }
}

private extension View {
    func percentHistoryScale(_ scale: HistoryPercentScale) -> some View {
        self
            .chartYScale(domain: scale.domain)
            .chartYAxis {
                AxisMarks(position: .leading, values: scale.axisValues) { value in
                    AxisGridLine()
                    AxisTick()
                    if let percent = value.as(Double.self) {
                        AxisValueLabel(percent.formatted(.number.precision(.fractionLength(0...3))) + "%")
                    }
                }
            }
    }

    func rateHistoryScale(_ scale: HistoryValueScale) -> some View {
        self
            .chartYScale(domain: scale.domain)
            .chartYAxis {
                AxisMarks(position: .leading, values: scale.axisValues) { value in
                    AxisGridLine()
                    AxisTick()
                    if let rate = value.as(Double.self) {
                        AxisValueLabel(rate.formatted(.number.precision(.fractionLength(0...2))))
                    }
                }
            }
    }
}

/// One row in an event log (used by the history tab and the system Activity view).
struct EventRow: View {
    let event: ActivityEvent
    var elevated = true
    /// When true, the row is highlighted (accent wash + dot) to mark an event the user hasn't seen yet.
    /// The Activity panel passes this; the per-container history tab leaves it false.
    var isUnread = false
    var onReadChange: (Bool) -> Void = { _ in }
    var onDelete: () -> Void = {}

    var body: some View {
        UI.Card.Scaffold(size: .small,
                     isSelected: isUnread,
                     elevated: elevated,
                     title: event.message,
                     subtitle: subtitle) {
            UI.Card.IconChip(symbol: event.kind.symbol,
                                 tint: event.kind.tint,
                                 backgroundOpacity: UI.Card.Metric.iconEmphasisBackgroundOpacity)
        } titleAccessory: {
            EmptyView()
        } subtitleAccessory: {
            UI.Badge.Text(text: event.kind.rawValue.capitalized)
        } headerAccessory: {
            if isUnread {
                UI.Badge.Dot(color: .accentColor)
                    .accessibilityLabel(AppText.unread)
            } else {
                EmptyView()
            }
        } bodyContent: {
            EmptyView()
        } footerLeading: {
            EmptyView()
        } footerActions: {
            EmptyView()
        } widget: {
            EmptyView()
        }
        .selectionFill()
        .contextMenu { rowMenu }
    }

    /// Relative time, plus the container's short id when the event is container-scoped.
    private var subtitle: String {
        var parts = [event.timestamp.formatted(.relative(presentation: .numeric))]
        if let id = event.containerID, !id.isEmpty { parts.append(String(id.prefix(12))) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var rowMenu: some View {
        if event.isRead {
            Button { onReadChange(false) } label: { Label("Mark as Unread", systemImage: "circle") }
        } else {
            Button { onReadChange(true) } label: { Label("Mark as Read", systemImage: "checkmark.circle") }
        }
        UI.Copy.ValueLabel("Copy Message", value: event.message)
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label("Delete Event", systemImage: "trash")
        }
    }
}

extension EventKind {
    /// A per-kind accent used for the event row's icon chip — gives the log visual texture and lets
    /// alerts/health transitions read at a glance.
    var tint: Color {
        switch self {
        case .lifecycle:   return .green
        case .image, .pull: return .blue
        case .compose:     return .purple
        case .build:       return .orange
        case .registry:    return .teal
        case .watchdog:    return .orange
        case .healthcheck: return .pink
        case .alert:       return .red
        case .system, .ui: return .secondary
        }
    }
}
